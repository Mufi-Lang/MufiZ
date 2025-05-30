#include <nan.h>

typedef struct TSLanguage TSLanguage;

extern "C" TSLanguage *tree_sitter_mufiz();

namespace {

NAN_METHOD(New) {}

NAN_METHOD(GetLanguage) {
  Nan::HandleScope scope;
  v8::Local<v8::External> language = Nan::New<v8::External>(tree_sitter_mufiz());
  info.GetReturnValue().Set(language);
}

NAN_MODULE_INIT(Init) {
  Nan::Set(target, Nan::New("name").ToLocalChecked(), Nan::New("mufiz").ToLocalChecked());
  Nan::SetMethod(target, "getLanguage", GetLanguage);
}

NODE_MODULE(tree_sitter_mufiz_binding, Init)

}