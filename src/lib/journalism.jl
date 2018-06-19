function getname(fips):
    if config["dataset"] == "counties"
        regions = readtable(loadpath("county-info.csv"), eltypes=[String, String, String, String, Float64, Float64, Float64, Float64, Float64, Float64, Float64])
        regions[regions[:FIPS] .== fips, :County]
    else
        fips
    end
end

function getpaper(fips):
    suffixes = ['News', 'News', 'News', 'News', 'News', 'News', 'News', 'News', 'News', 'News',
                'News', 'News', 'News', 'News', 'News', 'Daily', 'Daily', 'Daily', 'Daily', 'Daily',
                'Daily', 'Daily', 'Daily', 'Times', 'Times', 'Times', 'Times', 'Times', 'Times',
                'Times', 'Times', 'Times', 'Herald', 'Journal', 'Herald', 'Journal', 'Herald', 'Journal',
                'Herald', 'Journal', 'Herald', 'Journal', 'Herald', 'Journal',
                'Press', 'Tribune', 'Press', 'Tribune', 'Press', 'Tribune', 'Press', 'Tribune', 'Press', 'Tribune',
                'Sun', 'Star', 'Sun', 'Star', 'Sun', 'Star',
                'Gazette', 'Courier', 'Record', 'Post', 'Sentinel', 'Observer',
                'Gazette', 'Courier', 'Record', 'Post', 'Sentinel', 'Observer',
                'Democrat', 'Register', 'Enterprise', 'Reporter', 'Independent',
                'Chronicle', 'Leader', 'Citizen', 'Review', 'Weekly']
    getname(fips) * " " * (hash(fips) % length(suffixes))
end

