# Expert Analysis of Temporal FFORs

## 1. How to read the figures

The FFOR represents all `(P_pcc, Q_pcc)` pairs that the distribution grid can
present at the point of common coupling (PCC), given the available controls and
the model constraints.

The notebook uses the following sign convention:

- `P_pcc > 0`: active power imported from the upstream grid;
- moving left: reduce imports through greater local generation or lower
  heat-pump consumption;
- moving right: increase imports by curtailing PV or keeping heat pumps at
  their maximum consumption;
- moving down: inverters supply reactive power locally (`Q_pv > 0`), so the
  PCC imports less of it;
- moving up: inverters absorb reactive power (`Q_pv < 0`), so the PCC must
  import more of it.

### Building the contour with 72 directions

The solver does not directly know the complete shape of the FFOR. It can only
find the most extreme feasible point in a given direction. The code therefore
defines 72 angles evenly spaced over a full revolution:

`phi = 0, 5, 10, ..., 355 degrees`

For each angle, it builds the vector:

`(a, b) = (cos(phi), sin(phi))`

Gurobi then minimizes:

`a * P_pcc + b * Q_pcc`

subject to all electrical constraints. This function defines a line
`a*P + b*Q = constant`, perpendicular to vector `(a,b)`. Moving this line until
it first touches the feasible set produces an extreme point called a support
point.

Several directions illustrate the mechanism:

- `phi = 0 deg`: minimize `P_pcc`, giving the leftmost point;
- `phi = 90 deg`: minimize `Q_pcc`, giving the lowest point;
- `phi = 180 deg`: minimize `-P_pcc`, thus maximize `P_pcc` and find the
  right-hand side of the FFOR;
- `phi = 270 deg`: minimize `-Q_pcc`, thus maximize `Q_pcc` and find the
  highest point;
- intermediate angles find corners and sloping sides.

The 72 resulting points are sorted by angle. The code joins each point to the
next and connects the last point to the first. The displayed contour is
therefore a polygonal approximation of the true boundary. The plotted segments
do not represent additional optimizations; they are simply straight lines
drawn between neighboring solutions.

The number 72 is neither a physical grid property nor an FFOR constraint. It is
a numerical resolution choice:

- `360 / 72 = 5 degrees` between searches;
- fewer directions make the calculation faster but produce a coarser contour
  and may miss a small chamfer;
- more directions improve the description of curved sections or rapid changes
  in the binding constraint, but increase computation time;
- increasing from 72 to 144 directions gives a `2.5-degree` step and roughly
  doubles the number of optimizations.

For the complete figure, eight snapshots, two scenarios, and 72 directions
represent `8 * 2 * 72 = 1152` optimizations, each followed by AC validation.
Thus, 72 is a reasonable compromise between visual accuracy and computation
time.

Because the linearized optimization problem is convex, this method describes
its convex envelope well. A long face generally indicates that the same
constraint remains binding over several directions. A corner or chamfer marks
a change in the binding constraint. However, the line between two validated
points is not itself tested point by point using the AC calculation; it should
be understood as a graphical interpolation of the contour.

## 2. Constraints that shape the contours

For each bus other than the PCC, the model imposes:

`P_bus = P_pv + P_hp + P_load`

`Q_bus = Q_pv + Q_load`

with:

- `0 <= P_pv <= P_pv_available`;
- `P_hp_min <= P_hp <= 0`, where `P_hp_min` is negative;
- `-Q_pv_max <= Q_pv <= Q_pv_max`;
- `P_pv^2 + Q_pv^2 <= S_inv^2`;
- `0.90 <= V <= 1.10 p.u.` in the linearized model;
- `P_line^2 + Q_line^2 <= S_line_max^2`.

The current load mode is `FFOR_LOAD_MODE = "fixed"`. Ordinary active and
reactive loads therefore do not change between the eight cases. Temporal
variation mainly comes from PV availability and maximum heat-pump consumption.

The diagnostics show that:

- without BelalpSolar, the cumulative reactive limits of the local PV systems
  (`+/-0.873 MVAr`) form most horizontal faces;
- with BelalpSolar, the linearized voltage at `0.90` or `1.10 p.u.` often
  becomes the binding constraint on the upper and lower faces;
- no line exceeds 100% during AC validation; the observed maximum is about
  76.8% on the BelalpSolar connection line;
- the inverter capability circle is not binding at the four diagnosed
  cardinal points. Explicit reactive limits and voltages are more restrictive;
- AC validation gives minimum voltages of about 0.977 to 0.990 p.u., while the
  linearized model sometimes reaches 0.90 p.u. The linearized model is
  therefore conservative and distorts part of the contour.

## 3. Modeled BelalpSolar capability

BelalpSolar is modeled with:

- installed power: `8.1 MWp`;
- assumed minimum power factor: `cos(phi) = 0.95`;
- inverter apparent power: `8.1 / 0.95 = 8.526 MVA`;
- fixed reactive capability:
  `Qmax = 8.1 * tan(arccos(0.95)) = 2.662 MVAr`.

The model therefore allows BelalpSolar to operate between `-2.662` and
`+2.662 MVAr`, subject to the 8.526 MVA capability circle. This capability is
also available when `P_pv = 0`, which assumes nighttime inverter operation in
STATCOM mode. This is a strong technical assumption, not an automatic property
of the plant.

Together with the local PV systems, the theoretical aggregate reactive bound
becomes `+/-3.535 MVAr`. This value is not always reachable at the PCC because
of voltage constraints and the electrical locations of the inverters.

## 4. Starting points

The crosses are neither the center of the FFOR nor an optimum. They represent
the AC calculation obtained with:

- all available PV power injected;
- all heat pumps at their snapshot consumption;
- `Q_pv = 0` for all inverters;
- fixed ordinary loads.

| Case | Without BelalpSolar `(P,Q)` | With BelalpSolar `(P,Q)` | PV with Belalp | HP |
|---|---:|---:|---:|---:|
| Summer 07:00 | (8.539, 3.745) | (6.333, 3.711) | 2.899 MW | -0.333 MW |
| Summer 12:00 | (7.739, 3.734) | (3.285, 3.753) | 5.962 MW | -0.296 MW |
| Summer 18:00 | (9.209, 3.755) | (9.107, 3.749) | 0.131 MW | -0.318 MW |
| Summer 00:00 | (9.050, 3.752) | (9.050, 3.750) | 0 MW | -0.129 MW |
| Winter 07:00 | (12.964, 3.823) | (12.251, 3.792) | 0.756 MW | -4.043 MW |
| Winter 12:00 | (10.271, 3.771) | (5.440, 3.764) | 6.325 MW | -2.795 MW |
| Winter 18:00 | (12.323, 3.810) | (12.323, 3.807) | 0 MW | -3.350 MW |
| Winter 00:00 | (10.754, 3.780) | (10.754, 3.777) | 0 MW | -1.808 MW |

The cross is close to the right boundary in winter without BelalpSolar because
the heat pumps already consume nearly their maximum power. It is close to the
left boundary at noon with BelalpSolar because all available generation is
already being injected.

## 5. Side-by-side analysis

### Summer 07:00

**Without BelalpSolar, blue.** The starting point is `(8.539, 3.745)`. The left
face, down to `P = 8.200 MW`, mainly results from switching off the heat pumps
while local PV remains at `0.709 MW`. The right face at `P = 9.259 MW` combines
PV curtailment to zero with heat pumps at `-0.333 MW`. The bottom at
`Q = 2.862 MVAr` corresponds to maximum local-PV supply,
`Q_pv = +0.873 MVAr`. The top at `Q = 4.635 MVAr` corresponds to
`Q_pv = -0.873 MVAr`. The contour is nearly rectangular because neither
voltage nor line constraints are strongly dominant.

**With BelalpSolar, green.** The starting point moves to `(6.333, 3.711)` due
to `2.191 MW` from BelalpSolar. The left face at `P = 6.020 MW` is imposed by
maximum PV and stopped heat pumps. The right face returns to `P = 9.254 MW`,
almost as without Belalp, because all PV can be curtailed to zero. The bottom
at `Q = 1.196 MVAr` is limited by the linearized upper voltage of `1.10 p.u.`
before all theoretical reactive capability is used. The top at
`Q = 6.025 MVAr` reaches the linearized lower voltage of `0.90 p.u.`. The two
diagonals express the tradeoff: high active generation plus reactive supply
raises voltage, while high reactive absorption lowers it.

### Summer 12:00

**Without BelalpSolar, blue.** The starting point is `(7.739, 3.734)`. The left
boundary at `P = 7.438 MW` is obtained with `1.462 MW` of PV and stopped heat
pumps. The right boundary at `P = 9.221 MW` comes from zero PV and heat pumps
at `-0.296 MW`. The bottom at `Q = 2.852 MVAr` and top at `Q = 4.634 MVAr`
almost exactly match the `Q_pv = +/-0.873 MVAr` bounds. The rectangle is
therefore mainly the product of active PV/heat-pump bounds and the local-PV
reactive bound.

**With BelalpSolar, green.** The starting point becomes `(3.285, 3.753)` with
`5.962 MW` of total PV, including `4.500 MW` at Belalp. The left boundary at
`P = 3.064 MW` corresponds to maximum PV and stopped heat pumps; it already
requires reactive absorption to avoid overvoltage. The right boundary at
`P = 9.216 MW` corresponds to curtailing all PV. The bottom at
`Q = 1.205 MVAr` reaches `Vmax = 1.10 p.u.`. The top at `Q = 7.394 MVAr` uses
the total reactive bound `Q_pv = -3.535 MVAr`, including Belalp at
`-2.662 MVAr`, and also reaches `Vmin = 0.90 p.u.`. The long upper-right
diagonal means that increasing active imports increases voltage drop and
leaves less margin to absorb reactive power. The lower-left diagonal means
that, at high active generation, reactive injection must be reduced or
reactive power absorbed to remain below the maximum voltage.

### Summer 18:00

**Without BelalpSolar, blue.** The starting point `(9.209, 3.755)` contains
only `0.032 MW` of PV. The active width from `8.886` to `9.242 MW` therefore
comes almost entirely from modulating the heat pumps between zero and
`-0.318 MW`. The lower and upper faces remain the local bounds
`Q_pv = +/-0.873 MVAr`, giving `Q = 2.872` to `4.635 MVAr`.

**With BelalpSolar, green.** The starting point is `(9.107, 3.749)`, and Belalp
supplies only `0.099 MW`. The active width remains small: `8.783` to
`9.239 MW`. However, the bottom falls to `1.199 MVAr` due to inverter reactive
power, with the linearized upper voltage binding. The top is limited to
`3.914 MVAr` by the linearized lower voltage. Belalp then injects about
`+0.701 MVAr` to support its remote bus while other PV systems absorb reactive
power. This geographical allocation explains why aggregate capability does
not produce a simple symmetrical upward extension.

### Summer 00:00

**Without BelalpSolar, blue.** The starting point is `(9.050, 3.752)`. With no
active PV, the width from `8.918` to `9.053 MW` comes only from heat pumps,
limited to `0.129 MW`. The model nevertheless retains the reactive capability
of local PV inverters: the contour extends from `Q = 2.872` to `4.632 MVAr`.

**With BelalpSolar, green.** The active starting point is nearly unchanged
because Belalp produces zero. However, the model allows it to operate as a
nighttime reactive compensator. The bottom reaches `1.244 MVAr` and
`Vmax = 1.10 p.u.`. The top reaches only `3.818 MVAr` and
`Vmin = 0.90 p.u.`. At this point, Belalp injects about `+0.800 MVAr` to
maintain its voltage while local PV systems absorb more. The green shape is
therefore mainly a reactive FFOR under the nighttime STATCOM assumption.

### Winter 07:00

**Without BelalpSolar, blue.** The starting point `(12.964, 3.823)` is very
close to the right because heat pumps consume `4.043 MW`. The left boundary at
`P = 8.855 MW` is obtained by stopping them; the low PV output of `0.063 MW`
has little effect. The right boundary at `P = 13.028 MW` keeps heat pumps at
maximum and curtails PV. The bottom at `Q = 2.871 MVAr` comes from
`Q_pv = +0.873 MVAr`. At the top, `Q = 4.682 MVAr`,
`Q_pv = -0.873 MVAr`, and linearized voltage reaches `0.90 p.u.`; heat-pump
consumption must already be reduced to `3.545 MW`, creating the upper-right
chamfer.

**With BelalpSolar, green.** The starting point is `(12.251, 3.792)` with
`0.693 MW` from Belalp. The left boundary at `P = 8.147 MW` comes from stopped
heat pumps and full PV injection. The right boundary at `P = 13.031 MW` comes
from zero PV and maximum heat-pump consumption. The bottom at `Q = 0.454 MVAr`
requires almost all heat-pump consumption to offset the voltage-rise effect of
reactive injection. Conversely, the top at `Q = 4.476 MVAr` requires heat
pumps to be almost completely stopped to avoid undervoltage. The two long
green diagonals therefore represent active-reactive voltage coupling, not an
arbitrary reduction in capability.

### Winter 12:00

**Without BelalpSolar, blue.** The starting point `(10.271, 3.771)` combines
`1.462 MW` of PV with `2.795 MW` of heat-pump consumption. The left boundary at
`P = 7.438 MW` stops heat pumps with maximum PV. The right boundary at
`P = 11.759 MW` curtails PV and keeps heat pumps at maximum. The bottom at
`Q = 2.851 MVAr` is the maximum local reactive supply. The top at
`Q = 4.677 MVAr` combines the local absorption bound with the linearized lower
voltage; the upper-right corner is slightly clipped.

**With BelalpSolar, green.** The starting point moves to `(5.440, 3.764)` with
`6.325 MW` of PV, including `4.863 MW` at Belalp. The left boundary at
`P = 2.750 MW` stops heat pumps and retains almost all PV; Belalp already
absorbs its `2.662 MVAr` maximum to control voltage. The right boundary at
`P = 11.760 MW` curtails all PV and keeps heat pumps at `-2.795 MW`. The bottom
at `Q = 0.644 MVAr` reaches `Vmax = 1.10 p.u.`. The top at `Q = 7.420 MVAr`
reaches both the total reactive bound of `-3.535 MVAr` and
`Vmin = 0.90 p.u.`. The Belalp line is the most heavily loaded, but only to
about 76.8% in AC: it influences the shape without becoming the thermal limit.
This is the case in which BelalpSolar enlarges the FFOR the most.

### Winter 18:00

**Without BelalpSolar, blue.** The starting point `(12.323, 3.810)` contains no
active PV. The width from `8.917` to `12.322 MW` comes almost entirely from
heat pumps (`3.350 MW`). The bottom at `Q = 2.872 MVAr` is the maximum supply
from local inverters. The top at `Q = 4.679 MVAr` reaches the local absorption
bound and the lower voltage; heat pumps must be slightly reduced, producing
the clipped corner.

**With BelalpSolar, green.** Belalp produces no active power but retains its
assumed reactive function. The left boundary at `P = 8.916 MW` corresponds to
stopped heat pumps, and the right boundary at `P = 12.334 MW` to maximum heat
pumps. The bottom at `Q = 0.560 MVAr` is near the right because heat-pump
consumption helps contain the voltage rise caused by reactive injection. The
top at `Q = 3.818 MVAr` is near the left because reactive absorption and
heat-pump consumption would otherwise cause undervoltage together. The contour
slope directly expresses this coupling.

### Winter 00:00

**Without BelalpSolar, blue.** The starting point is `(10.754, 3.780)`. The
width from `8.919` to `10.753 MW` corresponds to modulating `1.808 MW` of heat
pumps. The reactive faces remain close to `Q = 2.872` and `4.660 MVAr`, with a
small undervoltage chamfer at the upper right.

**With BelalpSolar, green.** The active starting point is identical because PV
output is zero. The left boundary at `P = 8.916 MW` stops the heat pumps; the
right boundary at `P = 10.759 MW` keeps them at maximum. The bottom at
`Q = 0.852 MVAr` requires almost all heat-pump consumption to permit reactive
injection without overvoltage. Conversely, the top at `Q = 3.818 MVAr`
requires heat pumps to be almost stopped to avoid undervoltage. As at 18:00,
the green diagonal is the signature of the voltage constraint and the assumed
nighttime reactive operation of BelalpSolar.

## 6. Physical conclusions

1. Vertical faces mainly represent active-power saturation: maximum PV plus
   stopped heat pumps on the left, curtailed PV plus maximum heat pumps on the
   right.
2. Without BelalpSolar, horizontal faces mainly represent the cumulative
   reactive bounds of local PV systems, `+/-0.873 MVAr`.
3. With BelalpSolar, sloping faces are mainly created by linearized voltage
   limits. Supplying reactive power while generating substantial active power
   raises voltage; absorbing reactive power while consuming substantial active
   power lowers it.
4. The starting point is asymmetric by construction: maximum PV, heat pumps at
   their snapshot consumption, and zero reactive power. It must not be
   interpreted as the center of the FFOR.
5. Nighttime results with BelalpSolar depend entirely on the assumption that
   the inverter can operate as a STATCOM without solar generation. If this
   function is not contractually or technically available, impose `Q_pv = 0`
   whenever `P_pv_available = 0`.
6. The difference between the binding linearized voltage at 0.90/1.10 p.u. and
   actual AC voltages near 0.98/0.99 p.u. indicates that the green boundaries
   are conservative. For operational interpretation, the contour should be
   built with an AC loop or the sensitivities recalibrated around each
   snapshot.

The detailed values used in this analysis are stored in
`FFOR_temporal_constraint_diagnostics.csv`.
