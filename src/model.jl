## Complete Model construction
#
# Includes both water management and production management.

include("model-surfacewater.jl")

include("Market.jl");
include("Transportation.jl");
include("Groundwater.jl");

groundwater = initaquifer(model); # Allocation or optimization-only
transportation = inittransportation(model); # optimization-only
market = initmarket(model); # dep. Transportation, Agriculture

# Connect up the components
groundwater[:withdrawal] = allocation[:copy_gwextraction];

market[:produced] = agriculture[:allcropproduction];
market[:regionimports] = transportation[:regionimports];
market[:regionexports] = transportation[:regionexports];

