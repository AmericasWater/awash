using YAML

function readconfig(ymlpath)
    YAML.load(open(ymlpath))
end

function parsemonth(mmyyyy)
    parts = split(mmyyyy, '/')
    (parse(UInt16, parts[2]) - 1) * 12 + parse(UInt8, parts[1])
end

function getweather(variable)
    ncread("../data/VIC_WB.nc", variable)[config["startweather"]:config["startweather"]+numsteps-1, :]
end
