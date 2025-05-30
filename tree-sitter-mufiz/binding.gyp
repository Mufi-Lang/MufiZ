{
  "targets": [
    {
      "target_name": "tree_sitter_mufiz_binding",
      "include_dirs": [
        "<!(node -e \"require('nan')\")",
        "src"
      ],
      "sources": [
        "bindings/node/binding.cc",
        "src/parser.c"
      ],
      "cflags_c": [
        "-std=c99",
      ],
      "conditions": [
        ["OS=='win'", {
          "defines": [
            "_CRT_SECURE_NO_WARNINGS",
            "_CRT_NONSTDC_NO_DEPRECATE"
          ]
        }],
        ["OS=='mac'", {
          "xcode_settings": {
            "GCC_C_LANGUAGE_STANDARD": "c99"
          }
        }]
      ]
    }
  ]
}