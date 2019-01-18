function eachnoncomment(file)
    if typeof(file) <: AbstractString
        file = open(file)
    end

    function producer()
        for line in eachline(file)
            if line[1] != '#'
                produce(line)
            end
        end
    end

    Task(producer)
end
