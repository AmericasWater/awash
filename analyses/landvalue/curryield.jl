using CSV, NaNMath, DelimitedFiles, Missings

irrigation = CSV.read("irrigation.csv")

bayes_crops = ["Barley", "Corn", "Cotton", "Rice", "Soybean", "Wheat"]
edds_crops = ["Barley", "Maize", "Cotton", "Rice", "Soybeans", "Wheat"]
irr_crops = [:BARLEY, :CORN, :COTTON, :RICE, :SOYBEANS, :WHEAT]

maximum_yields = Dict("Barley" => 176.5, "Corn" => 246, "Cotton" => 3433.,
                      "Rice" => 10180, "Soybean" => 249, "Wheat" => 142.5)

cropdirs = ["barley", "corn", "cotton", "rice", "soybean", "wheat"]

knownareas = getfilteredtable("agriculture/knownareas.csv", :fips)

function preparecrop(crop, crossval, constvar, changeirr)
    ii = findfirst(bayes_crops .== crop)

    fullcropdir = "Code_" * cropdirs[ii]
    if crossval
        fullcropdir = fullcropdir * "_cv"
    end
    if constvar
        fullcropdir = fullcropdir * "_variance"
    end

    # Load degree day data
    gdds = CSV.read(joinpath(datapath("agriculture/edds/$(edds_crops[ii])-gdd.csv")), types=repeat([Union{Missing, Float64}], 61), missingstring="NA");
    kdds = CSV.read(joinpath(datapath("agriculture/edds/$(edds_crops[ii])-kdd.csv")), types=repeat([Union{Missing, Float64}], 61), missingstring="NA");

    bayes_intercept = readdlm(expanduser("~/Dropbox/Agriculture Weather/usa_cropyield_model/$fullcropdir/coeff_alpha.txt"), ' ')[:, 1:3111];
    bayes_time = readdlm(expanduser("~/Dropbox/Agriculture Weather/usa_cropyield_model/$fullcropdir/coeff_beta1.txt"), ' ')[:, 1:3111];
    bayes_wreq = readdlm(expanduser("~/Dropbox/Agriculture Weather/usa_cropyield_model/$fullcropdir/coeff_beta2.txt"), ' ')[:, 1:3111];
    bayes_gdds = readdlm(expanduser("~/Dropbox/Agriculture Weather/usa_cropyield_model/$fullcropdir/coeff_beta3.txt"), ' ')[:, 1:3111];
    bayes_kdds = readdlm(expanduser("~/Dropbox/Agriculture Weather/usa_cropyield_model/$fullcropdir/coeff_beta4.txt"), ' ')[:, 1:3111];

    if changeirr == true
        b0s = convert(Matrix{Float64}, readdlm(expanduser("~/Dropbox/Agriculture Weather/usa_cropyield_model/$fullcropdir/coeff_b0.txt"), ' '))
        b1s = convert(Matrix{Float64}, readdlm(expanduser("~/Dropbox/Agriculture Weather/usa_cropyield_model/$fullcropdir/coeff_b1.txt"), ' '))
        b2s = convert(Matrix{Float64}, readdlm(expanduser("~/Dropbox/Agriculture Weather/usa_cropyield_model/$fullcropdir/coeff_b2.txt"), ' '))
        b3s = convert(Matrix{Float64}, readdlm(expanduser("~/Dropbox/Agriculture Weather/usa_cropyield_model/$fullcropdir/coeff_b3.txt"), ' '))
        b4s = convert(Matrix{Float64}, readdlm(expanduser("~/Dropbox/Agriculture Weather/usa_cropyield_model/$fullcropdir/coeff_b4.txt"), ' '))
    else
        b0s = b1s = b2s = b3s = b4s = nothing
    end

    wreq_max = maximum(Missings.skipmissing(irrigation[:, Symbol("wreq$(irr_crops[ii])")]))

    return ii, gdds, kdds, bayes_intercept, bayes_time, bayes_wreq, bayes_gdds, bayes_kdds, b0s, b1s, b2s, b3s, b4s, wreq_max
end

function isextrapolate(fips, crop)
    ii = findfirst(bayes_crops .== crop)
    if ii == nothing
        ii = findfirst(edds_crops .== crop)
    end
    rr = findfirst(knownareas[:fips] .== fips)
    return knownareas[rr, irr_crops[ii]] == 0
end

function forceneg_coeff(draws)
    if (all(draws .> 0))
        draws .= 0
    else
        draws[draws .> 0] .= NaN
    end

    return draws
end

function getyield(rr, weatherrow, changeirr, trendyear, limityield, forceneg, prepdata)
    ii, gdds, kdds, bayes_intercept, bayes_time, bayes_wreq, bayes_gdds, bayes_kdds, b0s, b1s, b2s, b3s, b4s, wreq_max = prepdata

    if changeirr == true
        intercept = bayes_intercept[:, rr] + b0s[:, 6] * (irrigation[weatherrow, :irrfrac] - irrigation[weatherrow, irr_crops[ii]])
        time_coeff = bayes_time[:, rr] + b1s[:, 6] * (irrigation[weatherrow, :irrfrac] - irrigation[weatherrow, irr_crops[ii]])
        wreq_coeff = bayes_wreq[:, rr] + b2s[:, 6] * (irrigation[weatherrow, :irrfrac] - irrigation[weatherrow, irr_crops[ii]])
        gdds_coeff = bayes_gdds[:, rr] + b3s[:, 6] * (irrigation[weatherrow, :irrfrac] - irrigation[weatherrow, irr_crops[ii]])
        kdds_coeff = bayes_kdds[:, rr] + b4s[:, 6] * (irrigation[weatherrow, :irrfrac] - irrigation[weatherrow, irr_crops[ii]])
    else
        intercept = bayes_intercept[:, rr]
        wreq_coeff = bayes_wreq[:, rr]
        gdds_coeff = bayes_gdds[:, rr]
        kdds_coeff = bayes_kdds[:, rr]
        time_coeff = bayes_time[:, rr]
    end
    if forceneg # force kdds_coeff <= 0 and wreq_coeff <= 0
        wreq_coeff = forceneg_coeff(wreq_coeff)
        kdds_coeff = forceneg_coeff(kdds_coeff)
    end

    gdds1 = collect(gdds[weatherrow, end-9:end])
    kdds1 = collect(kdds[weatherrow, end-9:end])
    if all(Missings.ismissing.(gdds1)) || all(Missings.ismissing.(kdds1))
        return missing
    end

    gdds_row = collect(Missings.replace(gdds1, NaN))'
    kdds_row = collect(Missings.replace(kdds1, NaN))'
    time_row = trendyear # Give all yields as 2010; otherwise collect(1:61)
    if ismissing(irrigation[weatherrow, Symbol("wreq$(irr_crops[ii])")])
        wreq_row = wreq_max
    else
        wreq_row = irrigation[weatherrow, Symbol("wreq$(irr_crops[ii])")]
    end

    if changeirr == "skip"
        logyield = intercept .+ wreq_coeff * wreq_row .+ gdds_coeff * gdds_row .+ kdds_coeff * kdds_row .+ time_coeff * time_row
    else
        logyield = intercept .+ gdds_coeff * gdds_row .+ kdds_coeff * kdds_row .+ time_coeff * time_row
    end
    if limityield == "lybymc"
        logyield = vec(logyield)
        logyield[logyield .> log(maximum_yields[crop])] .= NaN
    end
    yield_total = NaNMath.mean(exp.(logyield))
    if limityield != "ignore" && yield_total > maximum_yields[crop]
        if limityield == "limity"
            yield_total = maximum_yields[crop]
        elseif limityield == "zeroy"
            yield_total = 0
        end
    end

    return yield_total
end
