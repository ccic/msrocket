import logging
import sys

# Logging levels for easy access
CRITICAL = logging.CRITICAL
FATAL = logging.FATAL
ERROR = logging.ERROR
WARNING = logging.WARNING
WARN = logging.WARN
INFO = logging.INFO
DEBUG = logging.DEBUG
NOTSET = logging.NOTSET

# Default basic format
DEF_CON_FORMAT = '%(asctime)s - %(filename)s[%(levelname)s]: %(message)s'


def setupBasicLogging(level=DEBUG):
    root = logging.getLogger()
    console = logging.StreamHandler(sys.stderr)
    console.setFormatter(logging.Formatter(DEF_CON_FORMAT))
    console.setLevel(level)
    root.addHandler(console)
    root.setLevel(level)

def getLogger(name='spider'):
    return logging.getLogger(name)
