"""Fetch the pinned historical Broadbalk table distributed by agridat."""
import hashlib
from pathlib import Path
from urllib.request import urlopen

REVISION = "d9fd2abaa3ebc925c10b05cd1aa4758d013c47a7"
URL = f"https://raw.githubusercontent.com/kwstat/agridat/{REVISION}/data/broadbalk.wheat.txt"
SHA256 = "7d7bce26436be6db72aff3ce0d8a179113b8223ab3521cef4f951719e130df55"


def main():
    output = Path("data/raw/broadbalk.wheat.tsv")
    if output.is_file() and hashlib.sha256(output.read_bytes()).hexdigest() == SHA256:
        print(output)
        return
    with urlopen(URL, timeout=30) as response:
        payload = response.read(100_001)
    if hashlib.sha256(payload).hexdigest() != SHA256:
        raise ValueError("Unexpected Broadbalk source SHA-256")
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix(".tmp")
    temporary.write_bytes(payload)
    temporary.replace(output)
    print(output)


if __name__ == "__main__":
    main()
