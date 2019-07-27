try:
    import socket
    import argparse
except ModuleNotFoundError:
    print('Make sure modules are installed correctly! ')


def findip(inputfile):
    with open(inputfile, "r") as ins:
        for line in ins:
            try:
                print(socket.gethostbyname(line.strip()))
            except Exception as e:
                print('-')


def main():
    # Arguments
    parser = argparse.ArgumentParser(description='ResolveIP')
    parser.add_argument("inputfile", help='File with (sub)domains')
    args = parser.parse_args()
    # Variables
    inputfile = args.inputfile
    try:
        findip(inputfile)
    except Exception as e:
        print(e)


if __name__ == "__main__":
    main()
