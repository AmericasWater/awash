## Installation instructions

1. Install "git", if you don't already have it.

   https://git-scm.com/downloads

2. Install "julia", version 4:

   http://julialang.org/downloads/

3. In a terminal, navigate to where you want to put the water model, and type:

   `git clone https://github.com/AmericasWater/operational-problem.git`

4. Open julia (I do this in the terminal) and type,

   `Pkg.add("Mimi")`
   `Pkg.add("Graphs")`
   `Pkg.add("NetCDF")`

    You may need to install other libraries for NetCDFs.

5. Use the development version of Mimi by calling

   `Pkg.checkout("Mimi")`

