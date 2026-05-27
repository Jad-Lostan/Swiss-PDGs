import gurobipy as gp
from gurobipy import GRB
import numpy as np
import scipy.sparse as sp	


# Create a new model
m = gp.Model("mip1") 
# Create variables
x = m.addVar(vtype=GRB.BINARY, name="x")
y = m.addVar(vtype=GRB.BINARY, name="y")
z = m.addVar(vtype=GRB.BINARY, name="z")
# Add constraint: x + 2 y + 3 z <= 4
m.addConstr(x + 2 * y + 3 * z <= 4, "c0")
m.addConstr(x + y >= 1, "c1")

# Set objective
m.setObjective(x + y + 2 * z, GRB.MAXIMIZE)
m.optimize()
for v in m.getVars():
    print('%s %g' % (v.VarName, v.X))
