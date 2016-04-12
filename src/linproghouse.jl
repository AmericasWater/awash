import Mimi.metainfo
import Mimi: CertainScalarParameter, CertainArrayParameter
import Base.*, Base.-

#export *

type LinearProgrammingHall
    component::Symbol
    name::Symbol
    f::Vector{Float64}
end

function hallsingle(model::Model, component::Symbol, name::Symbol, gen::Function)
    LinearProgrammingHall(component, name, matrixsingle(getdims(model, component, name), gen))
end

"""Connect a derivative to another component: change the variable component and name to another component."""
function hall_relabel(hall::LinearProgrammingHall, from::Symbol, tocomponent::Symbol, toname::Symbol)
    @assert hall.name == from "Name mismatch in hall_relabel: $(hall.name) <> $from"

    LinearProgrammingHall(tocomponent, toname, hall.f)
end

function -(hall::LinearProgrammingHall)
    LinearProgrammingHall(hall.component, hall.name, -hall.f)
end

type LinearProgrammingRoom
    varcomponent::Symbol
    variable::Symbol
    paramcomponent::Symbol
    parameter::Symbol
    A::SparseMatrixCSC{Float64, Int64}
end

function roomdiagonal(model::Model, component::Symbol, variable::Symbol, parameter::Symbol, gen::Function)
    dimsvar = getdims(model, component, variable)
    dimspar = getdims(model, component, parameter)
    @assert dimsvar == dimspar "Variable and parameter in roomdiagonal do not have the same dimensions: $dimsvar <> $dimspar"
    LinearProgrammingRoom(component, variable, component, parameter, matrixdiagonal(dimsvar, gen))
end

function roomintersect(model::Model, component::Symbol, variable1::Symbol, variable2::Symbol, gen::Function)
    dims1 = getdims(model, component, variable1)
    dims2 = getdims(model, component, variable2)
    LinearProgrammingRoom(component, variable1, component, variable2, matrixintersect(dims1, dims2, gen))
end

function roomfill(model::Model, component::Symbol, variable::Symbol, parameter::Symbol, gen::Function)
    dimsvar = getdims(model, component, variable)
    dimspar = getdims(model, component, parameter)
    @assert dimsvar == dimspar "Variable and parameter in roomfill do not have the same dimensions: $dimsvar <> $dimspar"
    LinearProgrammingRoom(component, variable, component, parameter, matrixsingle(dims, gen))
end

"""Connect a gradient to another component: change the variable component and name to another component."""
function room_relabel(room::LinearProgrammingRoom, from::Symbol, tocomponent::Symbol, toname::Symbol)
    @assert room.variable == from "Variable name mismatch in room_relabel: $(room.variable) <> $from"

    LinearProgrammingRoom(tocomponent, toname, room.paramcomponent, room.parameter, room.A)
end

"""Connect a gradient to another component: change the variable component and name to another component."""
function room_relabel_parameter(room::LinearProgrammingRoom, from::Symbol, tocomponent::Symbol, toname::Symbol)
    @assert room.parameter == from "Parameter name mismatch in room_relabel_parameter: $(room.variable) <> $from"

    LinearProgrammingRoom(room.varcomponent, room.variable, tocomponent, toname, room.A)
end

function *(hall::LinearProgrammingHall, room::LinearProgrammingRoom; skipnamecheck=false)
    if !skipnamecheck
        @assert room.variable == hall.name "Room * Hall name mismatch: $(room.parameter) <> $(hall.name); use room_relabel?"
    end
    LinearProgrammingHall(room.paramcomponent, room.parameter, vec(transpose(hall.f) * room.A))
end

function *(room1::LinearProgrammingRoom, room2::LinearProgrammingRoom; skipnamecheck=false)
    if !skipnamecheck
        @assert room1.parameter == room2.variable "Room * Room name mismatch: $(room1.parameter) <> $(room2.variable); use room_relabel?"
    end
    LinearProgrammingRoom(room1.varcomponent, room1.variable, room2.paramcomponent, room2.parameter, room1.A * room2.A)
end

function +(room1::LinearProgrammingRoom, room2::LinearProgrammingRoom; skipnamecheck=false)
    if !skipnamecheck
        @assert room1.parameter == room2.parameter "Room + Room parameter name mismatch: $(room1.parameter) <> $(room2.parameter); use room_relabel?"
        @assert room1.variable == room2.variable "Room + Room variable name mismatch: $(room1.variable) <> $(room2.variable); use room_relabel?"
    end
    LinearProgrammingRoom(room1.varcomponent, room1.variable, room1.paramcomponent, room1.parameter, room1.A + room2.A)
end

function -(room::LinearProgrammingRoom)
    LinearProgrammingRoom(room.varcomponent, room.variable, room.paramcomponent, room.parameter, -room.A)
end

function varsum(room::LinearProgrammingRoom)
    LinearProgrammingHall(room.paramcomponent, room.parameter, vec(sum(room.A, 1)))
end

type LinearProgrammingHouse
    model::Model
    paramcomps::Vector{Symbol}
    parameters::Vector{Symbol}
    constcomps::Vector{Symbol}
    constraints::Vector{Symbol}
    lowers::Vector{Float64}
    uppers::Vector{Float64}
    f::Vector{Float64}
    A::SparseMatrixCSC{Float64, Int64}
    b::Vector{Float64}
end

function LinearProgrammingHouse(model::Model, paramcomps::Vector{Symbol}, parameters::Vector{Symbol}, constcomps::Vector{Symbol}, constraints::Vector{Symbol})
    paramlen = sum(varlengths(model, paramcomps, parameters))
    variablelen = sum(varlengths(model, constcomps, constraints))
    A = spzeros(variablelen, paramlen)
    f = zeros(paramlen)
    b = zeros(variablelen)
    LinearProgrammingHouse(model, paramcomps, parameters, constcomps, constraints, zeros(length(f)), Inf * ones(length(f)), f, A, b)
end

function setobjective!(house::LinearProgrammingHouse, hall::LinearProgrammingHall)
    @assert hall.name in house.parameters "$(hall.name) not a known parameter"
    kk = findfirst((house.paramcomps .== hall.component) & (house.parameters .== hall.name))
    paramspans = varlengths(house.model, house.paramcomps, house.parameters)
    @assert length(hall.f) == paramspans[kk] "Length of parameter $(hall.name) unexpected: $(length(hall.f)) <> $(paramspans[kk])"
    before = sum(paramspans[1:kk-1])
    for ii in 1:paramspans[kk]
        #@assert house.f[before+ii] == 0 "Overwrite existing gradient in setobjective!"
        house.f[before+ii] = hall.f[ii]
    end
end

function setconstraint!(house::LinearProgrammingHouse, room::LinearProgrammingRoom)
    @assert room.variable in house.constraints "$(room.variable) not a known variable"
    @assert room.parameter in house.parameters "$(hall.parameter) not a known parameter"

    kk = findfirst((house.paramcomps .== room.paramcomponent) & (house.parameters .== room.parameter))
    ll = findfirst((house.constcomps .== room.varcomponent) & (house.constraints .== room.variable))
    paramspans = varlengths(house.model, house.paramcomps, house.parameters)
    constspans = varlengths(house.model, house.constcomps, house.constraints)
    @assert size(room.A, 1) == constspans[ll] "Length of variable $(room.variable) unexpected: $(size(room.A, 1)) <> $(constspans[ll])"
    @assert size(room.A, 2) == paramspans[kk] "Length of parameter $(room.parameter) unexpected: $(size(room.A, 2)) <> $(paramspans[kk])"

    parambefore = sum(paramspans[1:kk-1])
    constbefore = sum(constspans[1:ll-1])

    house.A[constbefore+1:constbefore+constspans[ll], parambefore+1:parambefore+paramspans[kk]] = room.A
end

function setconstraintoffset!(house::LinearProgrammingHouse, hall::LinearProgrammingHall)
    @assert hall.name in house.constraints "$(hall.name) not a known variable"
    kk = findfirst((house.constcomps .== hall.component) & (house.constraints .== hall.name))
    constspans = varlengths(house.model, house.constcomps, house.constraints)
    @assert length(hall.f) == constspans[kk] "Length of parameter $(hall.name) unexpected: $(length(hall.f)) <> $(constspans[kk])"
    before = sum(constspans[1:kk-1])
    for ii in 1:constspans[kk]
        #@assert house.b[before+ii] == 0 "Overwrite existing gradient in setobjective!"
        house.b[before+ii] = hall.f[ii]
    end
end

function clearconstraint!(house::LinearProgrammingHouse, component::Symbol, variable::Symbol)
    @assert variable in house.constraints "$(variable) not a known variable"

    ll = findfirst((house.constcomps .== component) & (house.constraints .== variable))
    constspans = varlengths(house.model, house.constcomps, house.constraints)

    constbefore = sum(constspans[1:ll-1])

    house.A[constbefore+1:constbefore+constspans[ll], :] = 0
    house.b[constbefore+1:constbefore+constspans[ll]] = 0
end

function setupper!(house::LinearProgrammingHouse, hall::LinearProgrammingHall)
    @assert hall.name in house.parameters "$(hall.name) not a known parameter"
    kk = findfirst((house.paramcomps .== hall.component) & (house.parameters .== hall.name))
    paramspans = varlengths(house.model, house.paramcomps, house.parameters)
    @assert length(hall.f) == paramspans[kk] "Length of parameter $(hall.name) unexpected: $(length(hall.f)) <> $(paramspans[kk])"
    before = sum(paramspans[1:kk-1])
    for ii in 1:paramspans[kk]
        #@assert house.b[before+ii] == 0 "Overwrite existing gradient in setobjective!"
        house.uppers[before+ii] = hall.f[ii]
    end
end

function gethouse(house::LinearProgrammingHouse, rr::Int64, cc::Int64)
    # Determine the row and column names
    varii = findlast(cumsum(varlengths(house.model, house.constcomps, house.constraints)) .< rr) + 1
    parii = findlast(cumsum(varlengths(house.model, house.paramcomps, house.parameters)) .< cc) + 1
    rrrelative = rr - sum(varlengths(house.model, house.constcomps, house.constraints)[1:varii-1])
    ccrelative = cc - sum(varlengths(house.model, house.paramcomps, house.parameters)[1:parii-1])
    vardims = getdims(house.model, house.constcomps[varii], house.constraints[varii])
    pardims = getdims(house.model, house.paramcomps[parii], house.parameters[parii])

    println("$(house.constcomps[varii]).$(house.constraints[varii])$(toindex(rrrelative, vardims)), $(house.paramcomps[parii]).$(house.parameters[parii])$(toindex(ccrelative, pardims)) = $(house.A[rr, cc])")
end

function constraining(house::LinearProgrammingHouse, solution::Vector{Float64})
    # Determine which constraint (if any) is stopping an increase or decrease of each
    df = DataFrame(solution=solution)
    df[:component] = :na
    df[:parameter] = :na
    df[:abovefail] = ""
    df[:belowfail] = ""

    # Produce names for all constraints
    varlens = varlengths(house.model, house.constcomps, house.constraints)
    names = ["" for ii in 1:sum(varlens)]
    for kk in 1:length(house.constcomps)
        ii0 = sum(varlens[1:kk-1])
        for ii in 1:varlens[kk]
            names[ii0 + ii] = "$(house.constraints[kk]).$ii"
        end
    end

    varlens = varlengths(house.model, house.paramcomps, house.parameters)
    baseconsts = house.A * solution

    println("Ignore:")
    println(join(names[find(baseconsts .> house.b)], ", "))
    ignore = baseconsts .> house.b

    for kk in 1:length(house.paramcomps)
        ii0 = sum(varlens[1:kk-1])
        for ii in 1:varlens[kk]
            df[ii0 + ii, :component] = house.paramcomps[kk]
            df[ii0 + ii, :parameter] = house.parameters[kk]

            newconst = baseconsts + house.A[:, ii0 + ii] * 1e-6
            df[ii0 + ii, :abovefail] = join(names[find((newconst .> house.b) & !ignore)], ", ")

            newconst = baseconsts - house.A[:, ii0 + ii] * 1e-6
            df[ii0 + ii, :belowfail] = join(names[find((newconst .> house.b) & !ignore)], ", ")
        end
    end

    df
end

function rangeof(m::Model, name, components, names)
    varlens = varlengths(m, components, names)
    kk = findfirst(name .== names)
    sum(varlens[1:kk-1])+1:sum(varlens[1:kk])
end

## Helpers

"Translate an offset value (+1) to an index vector."
function toindex(ii::Int64, dims::Vector{Int64})
    indexes = Vector{Int64}(length(dims))
    offset = ii - 1
    for dd in 1:length(dims)
        indexes[dd] = offset % dims[dd] + 1
        offset = floor(Int64, offset / dims[dd])
    end

    return indexes
end

"Translate an index vector to an offset (+1)."
function fromindex(index::Vector{Int64}, dims::Vector{Int64})
    offset = index[end]
    for ii in length(dims)-1:-1:1
        offset = (offset - 1) * dims[ii] + index[ii]
    end

    return offset
end

"Return a vector of the indices defining the parameter or variable."
function getdims(model::Model, component::Symbol, name::Symbol)
    if name in keys(model.parameters)
        if isa(model.parameters[name], CertainScalarParameter)
            Int64[1]
        elseif isa(model.parameters[name], CertainArrayParameter)
            Int64[size(model.parameters[name].values)...]
        end
    else
        meta = metainfo.getallcomps()
        convert(Vector{Int64}, map(dim -> model.indices_counts[dim], meta[(:Main, component)].variables[name].dimensions))
    end
end

"Return the total span occupied by each variable or parameter."
function varlengths(model::Model, components::Vector{Symbol}, names::Vector{Symbol})
    Int64[prod(getdims(model, components[ii], names[ii])) for ii in 1:length(components)]
end

## Matrix methods

"Construct a matrix with the given dimensions, calling gen for each element."
function matrixsingle(dims::Vector{Int64}, gen)
    f = Vector{Float64}(prod(dims))
    for ii in 1:length(f)
        f[ii] = gen(toindex(ii, dims)...)
    end

    f
end

"Call the generate function for all indices along the diagonal."
function matrixdiagonal(dims::Vector{Int64}, gen)
    dimlen = prod(dims)
    A = spzeros(dimlen, dimlen)
    for ii in 1:dimlen
        A[ii, ii] = gen(toindex(ii, dims)...)
    end

    A
end

"""
Call the generate function with all combinations of the shared
indices; shared dimensions must come in the same order and at the end
of the dimensions lists.
"""
function matrixintersect(rowdims::Vector{Int64}, coldims::Vector{Int64}, gen)
    A = spzeros(prod(rowdims), prod(coldims))

    # Determine shared dimensions: counting from 0 = end
    numshared = 0
    while numshared < min(length(rowdims), length(coldims))
        if rowdims[end - numshared] != coldims[end - numshared]
            break
        end
        numshared += 1
    end

    sharedims = rowdims[end - numshared + 1:end]
    sharedimslen = prod(sharedims)
    for ii in 1:sharedimslen
        index = toindex(ii, sharedims)
        topii = fromindex([ones(Int64, length(rowdims) - numshared); index], rowdims)
        bottomii = fromindex([rowdims[1:length(rowdims) - numshared]; index], rowdims)
        leftii = fromindex([ones(Int64, length(coldims) - numshared); index], coldims)
        rightii = fromindex([coldims[1:length(coldims) - numshared]; index], coldims)
        subA = sub(A, topii:bottomii, leftii:rightii)
        gen(subA, index...)
    end

    A
end
