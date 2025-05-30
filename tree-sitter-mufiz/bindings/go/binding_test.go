package tree_sitter_mufiz_test

import (
	"testing"

	tree_sitter "github.com/tree-sitter/go-tree-sitter"
	tree_sitter_mufiz "github.com/tree-sitter/tree-sitter-mufiz/bindings/go"
)

func TestCanLoadGrammar(t *testing.T) {
	language := tree_sitter.NewLanguage(tree_sitter_mufiz.Language())
	if language == nil {
		t.Errorf("Error loading MufiZ grammar")
	}
}
