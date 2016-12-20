Consider following the extended [tutorial 1](Tutorial%201%20-%20Running%20the%20model.ipynb) for more detailed directions.~

## Installation instructions

1. Install "git", if you don't already have it.

   https://git-scm.com/downloads

2. Install "julia", version 4:

   http://julialang.org/downloads/

3. In a terminal, navigate to where you want to put the water model, and type:

   `git clone https://github.com/AmericasWater/awash.git`

4. Open julia from the `src` directory (I do this in the terminal) and type,

   ```
   include("nui.jl")
   ```

## Basic usage

To simulate the model, run the `simulate.jl` script in julia:

```
include("simulate.jl")
```

Then to see the results, call `getdataframe(m, <component>, <name>)`, where `<component>` is a symbol for one of the components, for example `:Agriculture`; and `<name>` is a symbol for a output variable, for example `:production`.