using YAML

function readconfig(ymlpath)
    if ymlpath[1:11] == "../configs/"
        ymlpath = joinpath(dirname(@__FILE__), "../" * ymlpath)
    end

    YAML.load(open(ymlpath))
end

function parsemonth(mmyyyy)
    parts = split(mmyyyy, '/')
    (parse(UInt16, parts[2]) - 1) * 12 + parse(UInt8, parts[1])
end

function configdata(name, defpath, defcol)
    path = datapath(get(config, "$name-path", defpath))
    column = symbol(get(config, "$name-column", defcol))
    readtable(path)[:, column]
end
