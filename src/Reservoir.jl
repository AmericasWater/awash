## Reservoirs Component
#
# Manages the storage in reservoirs over time.

using Mimi
using Distributions
using SparseArrays

reservoirdata = getreservoirs(config)

@defcomp Reservoir begin
    reservoirs = Index()
    gauges = Index()
    scenarios = Index()

    # Streamflow connections from optim
    inflowsgauges = Parameter(index=[gauges, scenarios, time], unit="1000 m^3")
    outflowsgauges = Parameter(index=[gauges, scenarios, time], unit="1000 m^3")
    captures = Parameter(index=[reservoirs, scenarios, time], unit="1000 m^3") # positive or negative
    # Reservoir inflows
    inflows = Variable(index=[reservoirs, scenarios, time], unit="1000 m^3")
    outflows = Variable(index=[reservoirs, scenarios, time], unit="1000 m^3")
    # withdrawals
    withdrawals = Variable(index=[reservoirs, scenarios, time], unit="1000 m^3")
    # releases
    releases = Variable(index=[reservoirs, scenarios, time], unit="1000 m^3")

    # Evaporation
    evaporation = Parameter(index=[reservoirs, scenarios, time], unit="")

    # Storage
    storage = Variable(index=[reservoirs, scenarios, time], unit="1000 m^3")
    storage0 = Parameter(index=[reservoirs], unit="1000 m^3")
    storagecapacitymin = Parameter(index=[reservoirs], unit="1000 m^3")
    storagecapacitymax = Parameter(index=[reservoirs], unit="1000 m^3")

    # Cost of captures
    unitcostcaptures= Parameter(unit="\$/1000m3")
    cost = Variable(index=[reservoirs, scenarios, time], unit="\$")

    """
    Compute the storage for the reservoirs, the releases and the withdrawals from the reservoirs as they change in time
    """
    function run_timestep(p, v, d, tt)
        v.inflows[:, :, tt] = zeros(numreservoirs, numscenarios);
        v.outflows[:, :, tt] = zeros(numreservoirs, numscenarios);

        for gg in 1:numgauges
	    index = vertex_index(downstreamorder[gg])
	    if isreservoir[index] > 0
	        rr = isreservoir[index]
	        v.inflows[rr, :, tt] = p.inflowsgauges[gg, :, tt];
	        v.outflows[rr, :, tt] = p.outflowsgauges[gg, :, tt];
	    end
        end

        for rr in d.reservoirs
            v.cost[rr, :, tt] = p.unitcostcaptures*p.captures[rr, :, tt]
	    if is_first(tt)
	        v.storage[rr,:,tt] = (1 .- p.evaporation[rr,:,tt]).^config["timestep"]*p.storage0[rr] .+ p.captures[rr, :, tt]
	    else
	        v.storage[rr,:,tt] = (1 .- p.evaporation[rr,:,tt]).^config["timestep"].*v.storage[rr,:,tt-1] .+ p.captures[rr, :, tt]
	    end

            for ss in 1:numscenarios
	        if p.captures[rr,ss,tt]<0
		    v.withdrawals[rr,ss,tt] = -p.captures[rr,ss,tt] - (v.outflows[rr,ss,tt] - v.inflows[rr,ss,tt])
		    if v.inflows[rr,ss,tt]<v.outflows[rr,ss,tt]
		        v.releases[rr,ss,tt] = v.outflows[rr,ss,tt] - v.inflows[rr, ss, tt]
		    else
		        v.releases[rr,ss,tt] = 0
                    end
	        else
		    v.releases[rr,ss,tt] = 0
		    v.withdrawals[rr,ss,tt] = 0
	        end
            end
        end
    end
end

function initreservoir(m::Model, name=nothing)
    if name == nothing
        reservoir = add_comp!(m, Reservoir)
    else
        reservoir = add_comp!(m, Reservoir, name)
    end

    if config["dataset"] == "three"
        reservoir[:storagecapacitymax] = 8.2*ones(numreservoirs)
        reservoir[:storagecapacitymin] = 0.5*ones(numreservoirs)
        reservoir[:storage0] = 1.3*ones(numreservoirs)
        reservoir[:evaporation] = 0.01*ones(numreservoirs, numscenarios, numsteps)
    elseif "rescap" in keys(config) && config["rescap"] == "zero"
        reservoir[:storagecapacitymax] = zeros(numreservoirs);
       	reservoir[:storagecapacitymin] = zeros(numreservoirs);
       	reservoir[:storage0] = zeros(numreservoirs);
     	reservoir[:evaporation] = zeros(numreservoirs, numscenarios, numsteps);
    else
        rcmax = convert(Vector{Float64}, reservoirdata[!, :MAXCAP])./1000 #data in cubic meters, change to 1000m3
     	reservoir[:storagecapacitymax] = rcmax;
     	reservoir[:storagecapacitymin] = zeros(numreservoirs);
        storage0 = zeros(numreservoirs);
        if "reshalf" in keys(config) && config["reshalf"] == "half"
            storage0 = (rcmax-reservoir[:storagecapacitymin])/2; #half full
        end
        reservoir[:storage0] = storage0
        println(size(evaporation_matrix(storage0)))
        reservoir[:evaporation] = evaporation_matrix(storage0) #0.05*ones(numreservoirs, numscenarios, numsteps);
    end

    reservoir[:captures] = cached_fallback("extraction/captures", () -> zeros(numreservoirs, numscenarios, numsteps));
    reservoir[:outflowsgauges] = zeros(numgauges, numscenarios, numsteps);
    reservoir[:inflowsgauges] = zeros(numgauges, numscenarios, numsteps);

    reservoir[:unitcostcaptures] = 1.;
    reservoir
end


function grad_reservoir_outflows_captures(m::Model)
    function generate(A)
        # Fill in GAUGES x RESERVOIRS matrix
        # Propogate in downstream order
        for hh in 1:numgauges
            gg = vertex_index(downstreamorder[hh])
            gauge = downstreamorder[hh].label
            for upstream in out_neighbors(wateridverts[gauge], waternet)
                index = vertex_index(upstream, waternet)
                if isreservoir[index] > 0
                    A[gg, isreservoir[index]] = -1
                else
                    A[gg, :] += A[index, :]
                end
            end
        end
    end
    roomintersect(m, :WaterNetwork, :outflows, :Reservoir, :captures, generate, [:scenarios, :time], [:scenarios, :time])
end

function grad_reservoir_storage_captures(m::Model)
    roomchunks(m, :Reservoir, :storage, :captures, (vss, vtt, pss, ptt) -> ifelse(vtt >= ptt && vss == pss, spdiagm(0 => (1 .- m.md.external_params[:evaporation].values[:, vss, vtt]).^(config["timestep"]*(vtt-ptt))), spzeros(numreservoirs, numreservoirs)), [:scenarios, :time], [:scenarios, :time])
end

function constraintoffset_reservoir_storagecapacitymin(m::Model)
    gen(rr) = m.md.external_params[:storagecapacitymin].values[rr]
    hallsingle(m, :Reservoir, :storage, gen, [:scenarios, :time])
end

function constraintoffset_reservoir_storagecapacitymax(m::Model)
    gen(rr) = m.md.external_params[:storagecapacitymax].values[rr]
    hallsingle(m, :Reservoir, :storage, gen, [:scenarios, :time])
end

function constraintoffset_reservoir_storage0(m::Model)
    gen(rr, ss, tt) = (1 .- m.md.external_params[:evaporation].values[rr, ss, tt])^(tt*config["timestep"]) * m.md.external_params[:storage0].values[rr]
    hallsingle(m, :Reservoir, :storage, gen)
end

function grad_reservoir_cost_captures(m::Model)
    roomdiagonal(m, :Reservoir, :cost, :captures, m.md.external_params[:unitcostcaptures].value)
end
