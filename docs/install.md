## Installation instructions

1. Install "git", if you don't already have it.

   https://git-scm.com/downloads

2. Install "julia", version 4:

   http://julialang.org/downloads/

3. In a terminal, navigate to where you want to put the water model, and type:

   `git clone https://github.com/AmericasWater/operational-problem.git`

4. Open julia (I do this in the terminal) and type,

   ```
   Pkg.add("Mimi")
   Pkg.add("Graphs")
   Pkg.add("NetCDF")
   ```

    You may need to install other libraries for NetCDFs.

5. Use the development version of Mimi by calling

   `Pkg.checkout("Mimi")`

6. If you want to do optimization, install James's version of OptiMimi:

```
Pkg.add("OptiMimi")
Pkg.checkout("OptiMimi")
```

## Basic usage

To simulate the model, run the `simulate.jl` script in julia:

```
include("simulate.jl")
```

Then to see the results, call `getdataframe(m, <component>, <name>)`, where `<component>` is a symbol for one of the components, for example `:Agriculture`; and `<name>` is a symbol for a output variable, for example `:production`.