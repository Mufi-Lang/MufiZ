# Product Guidelines - MufiZ

## Documentation and Communication Tone
- **Technical & Precise:** Prioritize mathematical accuracy and performance metrics. Documentation should provide deep dives into the VM's behavior and the implementation details of numerical methods.
- **Educational & Approachable:** Use clear examples and step-by-step guides for new features, ensuring the language remains accessible despite its technical depth.
- **Experimental & Forward-Looking:** Embrace the project's identity as a laboratory for language design, encouraging users to explore and push the limits of Mufi-Lang.

## Visual Identity and Brand Messaging
- **Mathematical Rigor:** Emphasize the language's strengths in scientific computing through precise terminology and examples drawn from data science and linear algebra.
- **Experimental & Modern:** Maintain a clean, minimalist aesthetic that highlights "Mufi-Lang" as a cutting-edge frontier in scripting.

## Community and Evolution
- **Guided Evolution:** Prioritize contributions and feature requests that align with the core roadmap, specifically those enhancing numerical methods and data serialization.
- **Consistency & Performance:** All additions must maintain high-performance characteristics and seamless integration with the Zig ecosystem.

## Coding Standards (Mufi-Lang)
- **Naming Conventions:** Use `snake_case` for functions, variables, and module names to ensure a consistent experience for developers coming from Zig.
- **Clarity over Brevity:** While the syntax is expressive, prioritize code that is readable and easy to maintain.

## Error Handling and Diagnostics
- **Detailed & Contextual:** Compiler and VM diagnostics must provide precise location data (line/column) and helpful suggestions for resolving errors.
- **Standardized Formats:** Ensure error output is strictly consistent to support the development of automated tooling and LSP integrations.
