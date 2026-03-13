//! LSP server — wires `complete` and `diagnose` into a JSON-RPC Language Server.
//!
//! Protocol: stdin/stdout, full-document sync.
//!   • textDocument/completion   → calls `infer::complete()`
//!   • textDocument/didOpen|didChange → calls `infer::diagnose()` + publishDiagnostics
//!   • textDocument/didClose     → clears diagnostics

use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Arc;

use anyhow::Result;
use tokio::sync::Mutex;
use tower_lsp::jsonrpc;
use tower_lsp::lsp_types::*;
use tower_lsp::{Client, LanguageServer, LspService, Server};

use crate::infer::LoadedModel;

// ------------------------------------------------------------------ //
// Backend
// ------------------------------------------------------------------ //

struct Backend {
    client: Client,
    model: Arc<Mutex<LoadedModel>>,
    docs: Arc<Mutex<HashMap<Url, String>>>,
}

impl Backend {
    fn new(client: Client, model: LoadedModel) -> Self {
        Self {
            client,
            model: Arc::new(Mutex::new(model)),
            docs: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    /// Run diagnostics on `text` and publish them to the client.
    async fn publish_diags(&self, uri: Url, text: String) {
        let model = self.model.lock().await;
        let raw = match crate::infer::diagnose(&*model, &text) {
            Ok(d) => d,
            Err(e) => {
                self.client
                    .log_message(MessageType::ERROR, format!("diagnose error: {e}"))
                    .await;
                return;
            }
        };
        drop(model);

        let diagnostics: Vec<Diagnostic> = raw
            .iter()
            // Only surface "error" items in the editor — warnings are noisy on
            // statistically long programs and kept only for bench/analysis.
            .filter(|d| d.severity == "error")
            .map(|d| {
                let start = byte_to_position(&text, d.start_byte);
                let end = byte_to_position(&text, d.end_byte);
                Diagnostic {
                    range: Range { start, end },
                    severity: Some(DiagnosticSeverity::ERROR),
                    message: d.message.clone(),
                    source: Some("mufi-neural".to_string()),
                    ..Default::default()
                }
            })
            .collect();

        self.client
            .publish_diagnostics(uri, diagnostics, None)
            .await;
    }
}

// ------------------------------------------------------------------ //
// LanguageServer trait impl
// ------------------------------------------------------------------ //

#[tower_lsp::async_trait]
impl LanguageServer for Backend {
    async fn initialize(&self, _params: InitializeParams) -> jsonrpc::Result<InitializeResult> {
        Ok(InitializeResult {
            capabilities: ServerCapabilities {
                // Full-document sync: editor sends the whole file on every change.
                text_document_sync: Some(TextDocumentSyncCapability::Kind(
                    TextDocumentSyncKind::FULL,
                )),
                completion_provider: Some(CompletionOptions {
                    trigger_characters: Some(vec![
                        " ".to_string(),
                        "(".to_string(),
                        ",".to_string(),
                        "=".to_string(),
                        ".".to_string(),
                    ]),
                    resolve_provider: Some(false),
                    ..Default::default()
                }),
                ..Default::default()
            },
            server_info: Some(ServerInfo {
                name: "mufi-neural-lsp".to_string(),
                version: Some(env!("CARGO_PKG_VERSION").to_string()),
            }),
        })
    }

    async fn initialized(&self, _: InitializedParams) {
        self.client
            .log_message(MessageType::INFO, "mufi-neural LSP ready")
            .await;
    }

    async fn shutdown(&self) -> jsonrpc::Result<()> {
        Ok(())
    }

    // ---- document lifecycle ----------------------------------------

    async fn did_open(&self, params: DidOpenTextDocumentParams) {
        let uri = params.text_document.uri.clone();
        let text = params.text_document.text.clone();
        self.docs.lock().await.insert(uri.clone(), text.clone());
        self.publish_diags(uri, text).await;
    }

    async fn did_change(&self, params: DidChangeTextDocumentParams) {
        let uri = params.text_document.uri.clone();
        // Full-sync: last entry is the whole document.
        if let Some(change) = params.content_changes.into_iter().last() {
            let text = change.text.clone();
            self.docs.lock().await.insert(uri.clone(), text.clone());
            self.publish_diags(uri, text).await;
        }
    }

    async fn did_close(&self, params: DidCloseTextDocumentParams) {
        let uri = params.text_document.uri.clone();
        self.docs.lock().await.remove(&uri);
        // Clear stale diagnostics.
        self.client.publish_diagnostics(uri, vec![], None).await;
    }

    // ---- completion ------------------------------------------------

    async fn completion(
        &self,
        params: CompletionParams,
    ) -> jsonrpc::Result<Option<CompletionResponse>> {
        let uri = params.text_document_position.text_document.uri.clone();
        let pos = params.text_document_position.position;

        let text = {
            let docs = self.docs.lock().await;
            match docs.get(&uri) {
                Some(t) => t.clone(),
                None => return Ok(None),
            }
        };

        let prefix = text_before_cursor(&text, pos);

        let model = self.model.lock().await;
        let candidates = crate::infer::complete(&*model, &prefix, 10).unwrap_or_default();
        drop(model);

        let items: Vec<CompletionItem> = candidates
            .into_iter()
            .enumerate()
            .map(|(rank, c)| {
                let label = c.text.trim().to_string();
                let kind = infer_completion_kind(&label);
                CompletionItem {
                    label: label.clone(),
                    kind: Some(kind),
                    detail: Some(format!("score: {:.3}", c.score)),
                    // sort_text ensures model-rank order is preserved in the editor list.
                    sort_text: Some(format!("{:04}", rank)),
                    insert_text: Some(label),
                    ..Default::default()
                }
            })
            .collect();

        Ok(Some(CompletionResponse::Array(items)))
    }
}

// ------------------------------------------------------------------ //
// Entry point
// ------------------------------------------------------------------ //

/// Start the LSP server, communicating over stdin / stdout.
pub async fn run_lsp(tokenizer: PathBuf, checkpoint: PathBuf, cpu: bool) -> Result<()> {
    let model = LoadedModel::load(&tokenizer, &checkpoint, cpu)?;

    let stdin = tokio::io::stdin();
    let stdout = tokio::io::stdout();

    let (service, socket) = LspService::new(|client| Backend::new(client, model));
    Server::new(stdin, stdout, socket).serve(service).await;
    Ok(())
}

// ------------------------------------------------------------------ //
// Helpers
// ------------------------------------------------------------------ //

/// Convert a UTF-8 byte offset to an LSP `Position` (line + UTF-16 character).
fn byte_to_position(text: &str, byte_offset: usize) -> Position {
    let safe = byte_offset.min(text.len());
    // Guard against splitting a multi-byte char.
    let safe = (0..=safe)
        .rev()
        .find(|&i| text.is_char_boundary(i))
        .unwrap_or(0);

    let prefix = &text[..safe];
    let line = prefix.chars().filter(|&c| c == '\n').count() as u32;
    let last_line = prefix.rfind('\n').map(|p| &prefix[p + 1..]).unwrap_or(prefix);
    let character = last_line.encode_utf16().count() as u32;
    Position { line, character }
}

/// Extract all source text that appears before the given LSP cursor position.
fn text_before_cursor(text: &str, pos: Position) -> String {
    let mut line = 0u32;
    let mut col = 0u32;

    for (bi, ch) in text.char_indices() {
        if line == pos.line && col == pos.character {
            return text[..bi].to_string();
        }
        if ch == '\n' {
            line += 1;
            col = 0;
        } else {
            col += 1;
        }
    }
    // Cursor is at (or past) end of document.
    text.to_string()
}

/// Map a completion token to the most appropriate LSP `CompletionItemKind`.
fn infer_completion_kind(token: &str) -> CompletionItemKind {
    const KEYWORDS: &[&str] = &[
        "var", "fun", "if", "else", "while", "for", "foreach",
        "return", "print", "println", "true", "false", "nil",
        "in", "and", "or", "not", "import", "break", "continue",
    ];
    const FUNCTIONS: &[&str] = &[
        "abs", "min", "max", "sqrt", "pow", "floor", "ceil",
        "len", "append", "pop", "push", "contains", "slice",
        "to_string", "to_int", "to_float",
        "type_of", "is_nil", "is_string", "is_number", "is_bool", "is_int",
        "printf", "input", "now_ms", "format", "exit", "assert",
        "print", "println", "ln",
    ];

    if KEYWORDS.contains(&token) {
        CompletionItemKind::KEYWORD
    } else if FUNCTIONS.contains(&token) {
        CompletionItemKind::FUNCTION
    } else if token.chars().next().map_or(false, |c| c.is_alphabetic() || c == '_') {
        CompletionItemKind::VARIABLE
    } else {
        CompletionItemKind::OPERATOR
    }
}
