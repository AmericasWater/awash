## Water Right Component
# Allows to define upper bound on withdrawals at the region level
# for the total time horizon or at the timestep level.
# To come: constraint at the yearly-level

using Mimi
using DataFrames


@defcomp WaterRight begin
    regions = Index()
    canals = Index()

    swrighttimestep = Parameter(index=[regions, time], unit="1000 m^3")
    gwrighttimestep = Parameter(index=[regions, time], unit="1000 m^3")
    swtimestep = Parameter(index=[canals, time], unit="1000 m^3")
    gwtimestep = Parameter(index=[regions, time], unit="1000 m^3")

    swrighttotal = Parameter(index=[regions], unit="1000 m^3")
    gwrighttotal = Parameter(index=[regions], unit="1000 m^3")
    swtotal = Variable(index=[regions], unit="1000 m^3")
    gwtotal = Variable(index=[regions], unit="1000 m^3")
    #totalrighttotaltime = Variable(index=[regions], unit="1000 m^3")

    """
    Compute the amount extracted and the cost for doing it.
    """
    function run_timestep(p, v, d, tt)
        # not sure if useful ...
        if tt == 1
            swtotal = zeros(numregions)
            gwtotal = zeros(numregions)
        end

        for pp in 1:nrow(draws)
            regionids = regionindex(draws, pp)
            rr = findfirst(regionindex(masterregions, :) .== regionids)
            if rr != nothing
                v.swtotal[rr] += p.swtimestep[pp, tt]
            end
        end

        for rr in d.regions
            v.gwtotal[rr] += p.gwtimestep[rr, tt]
        end

    end
end

"""
Add a WaterRight component to the model.
"""
function initwaterright(m::Model)
    waterright = add_comp!(m, WaterRight);

    # Water rights defined as USGS extraction values to start
    recorded = knowndf("exogenous-withdrawals")
    waterright[:swrighttimestep] = repeat(convert(Vector, recorded[:,:TO_SW]) * config["timestep"] * 1383. / 12., outer=[1, numsteps]);
    waterright[:gwrighttimestep] = repeat(convert(Vector, recorded[:,:TO_GW]) * config["timestep"] * 1383. / 12., outer=[1, numsteps]);
    waterright[:swrighttotal] = convert(Vector, recorded[:,:TO_SW]) * numsteps * 1383. / 12. * config["timestep"];
    waterright[:gwrighttotal] = convert(Vector, recorded[:,:TO_GW]) * numsteps * 1383. / 12. * config["timestep"];
    waterright[:gwtimestep] = zeros(numregions,numsteps)
    waterright[:swtimestep] = zeros(numcanals,numsteps)

    waterright
end

function grad_waterright_swtotal_withdrawals(m::Model)
    function generate(A)
        # Fill in COUNTIES x CANALS matrix
        for pp in 1:nrow(draws)
            rr_ = findfirst(regionindex(masterregions, :) .== regionindex(draws, pp))
            if rr_ != nothing
                A[rr_,pp] = 1.
            end
        end
    end
    roomintersect(m, :WaterRight, :swtotal, :swtimestep, generate, [:empty], [:time])
end

function constraintoffset_waterright_swrighttotal(m::Model)
    hallsingle(m, :WaterRight, :swtotal, (rr) -> m.md.external_params[:swrighttotal].values[rr])
end

function grad_waterright_gwtotal_waterfromgw(m::Model)
    function generate(A)
        for tt in 1:numsteps
            for rr in 1:numcounties
                A[rr, rr] = 1
            end
        end
        return A
    end

    roomintersect(m, :WaterRight, :gwtotal, :gwtimestep, generate)#, [:empty], [:time])
end

function constraintoffset_waterright_gwrighttotal(m::Model)
    hallsingle(m, :WaterRight, :gwtotal, (rr) -> m.md.external_params[:gwrighttotal].values[rr])
end
