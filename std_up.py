import toml

# Load TOML data
with open('stdlib.toml', 'r') as toml_file:
    functions_data = toml.load(toml_file)

# Function to update markdown content
def update_markdown(markdown_file, functions_data):
    # Create top header
    updated_content = ["# MufiZ Standard Library\n\n"]

    # Update markdown content based on TOML data
    for category, functions in functions_data.items():
        updated_content.append(f"## {category}\n\n")
        for function in functions:
            checkbox = "[X]" if function['implemented'] else "[ ]"
            name = function['name']
            return_type = function.get('return_type', '???')
            parameters = function.get('parameters', [])
            signature = f"- {checkbox} `{name}`\n"
            signature += f"  - Return Type: {return_type}\n"
            if parameters:
                parameters_str = ', '.join(parameters)
                signature += f"  - Parameters: {parameters_str}\n"
            updated_content.append(signature)
        updated_content.append("\n")

    # Write updated markdown content
    with open(markdown_file, 'w') as file:
        file.writelines(updated_content)

# Update markdown file
update_markdown('stdlib.md', functions_data)
