from .baking import baking
from .logger import get_logger

log = get_logger(__name__)


def main():
    log.info("Starting Baking Application")
    baking()


if __name__ == "__main__":
    main()
