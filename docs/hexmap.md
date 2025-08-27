A "hexmap p q" refers to using axial coordinates to address hexagons on a hex grid, where p and q represent the two axes. This system is a simplification of the three-dimensional cube coordinate system and is commonly used in video games and simulations. 

Axial coordinates (p, q) 

Instead of a standard rectangular (x, y) coordinate system, an axial system uses two of the three axes of a 3D cube grid, with the third value being implicit. 

* The origin: The central hex is typically (0, 0).

* The axes: There is a p-axis and a q-axis, typically 60° or 120° apart.

* Grid layout: The grid can be oriented with "pointy" or "flat" top hexagons, which affects how the p and q axes align and how coordinates translate to a graphical display. 

How it works with cube coordinates (p, q, s) 

The axial system is derived from a 3D cube coordinate system (p, q, s) where the sum of the coordinates is always zero: \(p+q+s=0\). Since s can be derived from p and q (\(s=-p-q\)), it is redundant to store and can be dropped for simplicity. 

The cube coordinates simplify calculations for common hex grid tasks: 

* Distance: The distance between two hexes A and B can be found using their cube coordinates: (abs(A.p - B.p) + abs(A.q - B.q) + abs(A.s - B.s)) / 2.

* Pathfinding: Pathfinding and line-drawing algorithms are cleaner with axial coordinates than with other systems like "offset coordinates". 

Comparison with other systems

Axial vs. Offset coordinates

* Offset coordinates are a more common but less mathematically elegant system that represents the hex grid as a standard rectangular (x, y) array. It's easy to store in a 2D array but can lead to complex algorithms for distance and pathfinding because of the staggered rows.

* Axial coordinates offer a mathematical simplicity for grid calculations. They are generally preferred for game logic and algorithms, even though they may be less intuitive for simple map storage. 

Axial vs. Cube coordinates

* Cube coordinates are excellent for mathematical operations and understanding the underlying geometry, as all six neighbors of a hex can be found by adding or subtracting one from a single axis.

* Axial coordinates are a more compact storage representation, as they only require two numbers per hex. The third coordinate can be calculated on the fly whenever a cube coordinate-specific algorithm is used. 

