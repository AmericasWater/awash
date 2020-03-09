DOWNSTREAM_FACTOR = 0.99 # amount that survives to downstream nodes
CANAL_FACTOR = (1 / .99) # amount needed to withdrawal to arrive in canal

function matrix_gauges_canals(A::AbstractMatrix{Float64}, canal_values::Vector{Float64})
    # Fill in GAUGES x CANALS matrix with local relationships
    for pp in 1:nrow(draws)
        gaugeid = draws[pp, :gaugeid]
        vertex = get(wateridverts, gaugeid, nothing)
        if vertex == nothing
            println("Missing $gaugeid")
        else
            gg = vertex_index(vertex)
            A[gg, pp] = canal_values[pp]
        end
    end
end

function matrix_downstreamgauges_canals(A::AbstractMatrix{Float64})
    # Propogate in downstream order
    for hh in 1:numgauges
        gg = vertex_index(downstreamorder[hh])
        gauge = downstreamorder[hh].label
        for upstream in out_neighbors(wateridverts[gauge], waternet)
            index = vertex_index(upstream, waternet)
            A[gg, :] += A[index, :]
        end
    end
end

# function evaporation(temp, latitude, month)
#     daylighthours = 4 * latitude * sin(0.53 * month - 1.65) + 12
#     if abs(latitude) > 23.5 * pi / 180
#         Ra = 3 * daylighthours * sin(0.131 * daylighthours - 0.95 * latitude)
#     else
#         Ra = 118 * daylighthours^0.2 * sin(0.131*daylighthours - 0.2 * latitude)
#     end
# end
