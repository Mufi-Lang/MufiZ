import hashlib
import requests

def get_url_hash(url):
    # Send a GET request to the URL
    response = requests.get(url)

    # Create a SHA256 hash object
    sha256_hash = hashlib.sha512()

    # Update the hash object with the response content
    sha256_hash.update(response.content)

    # Get the hexadecimal representation of the hash
    hash_hex = sha256_hash.hexdigest()

    return hash_hex

# Example usage
url = "https://github.com/Mustafif/zig-clap/archive/refs/tags/v0.8.1.tar.gz"
hash_value = get_url_hash(url)
print(hash_value)
