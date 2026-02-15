# Product Guidelines: MufiZ

## Technical Communication
- **Explicit and Educational:** Error messages and technical output should provide context and suggest potential fixes. The goal is to educate the user or contributor on the underlying concept rather than just reporting a failure.
- **Precision:** Use technically accurate terminology consistently across the compiler, REPL, and documentation.

## Documentation & Tone
- **Pragmatic and Technical:** Communication should be direct, efficient, and technically precise. Focus on "how-to" and "why," valuing clarity and engineering rigor over flowery prose.
- **Developer-Centric:** Assume an audience of developers who value understanding the "metal" and the internal mechanics of the system.

## Language Design Principles
- **Explicitness over Implicitness:** Favor clear, readable code where intent is obvious. Avoid "magic" or hidden control flow, aligning with the philosophy of the Zig ecosystem.
- **Consistency and Orthogonality:** Language features and standard library modules must behave predictably and consistently across different use cases.
- **Performance-First:** Design choices should prioritize efficient execution and provide the developer with the tools necessary to optimize their code (e.g., native vector and hash table support).
