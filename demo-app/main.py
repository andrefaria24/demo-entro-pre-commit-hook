import os


def main() -> None:
    port = int(os.environ.get("PORT", "8080"))
    print(f"Orders service starting on port {port}")


if __name__ == "__main__":
    main()
