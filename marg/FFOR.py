import gurobipy as gp
from gurobipy import GRB

model = gp.Model()

P_pv[k]      # production PV
P_hp[k]      # consommation HP
P[k]         # injection nodale
theta[k]     # angle

P_pv = model.addVars(nodes, lb=0)
P_hp = model.addVars(nodes, lb=0)
P    = model.addVars(nodes)
theta = model.addVars(nodes)

for k in nodes:
    model.addConstr(
        P[k] == P_pv[k] - P_hp[k] - P_load[k]
    )

for k in nodes:
    model.addConstr(P_pv[k] <= P_pv_max[k])

for k in nodes:
    model.addConstr(P_hp[k] <= P_hp_max[k])

P_pcc = P[19]

model.setObjective(
    alpha * (P_pcc - P_base) +
    beta  * (Q_pcc - Q_base),
    GRB.MAXIMIZE
)

model.setObjective(
    alpha * (P_pcc - P_base) +
    beta  * (Q_pcc - Q_base),
    GRB.MAXIMIZE
)

model.optimize()