import pandapower as pp
def test_installation():
    return pp.__version__
version = test_installation()
print(version)