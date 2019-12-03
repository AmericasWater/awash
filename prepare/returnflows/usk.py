import sys, csv
import numpy as np
sys.path.append("/Users/jrising/projects/research-common/python")
sys.path.append("/Users/jrising/projects/research-common/python/geogrid")
sys.path.append("/Users/jrising/projects/research-common/python/physical")
import soil

hwsd = soil.HWSDSoil("../../../soil", False)
with open("us-soils.csv", 'w') as fp:
    writer = csv.writer(fp)
    writer.writerow(['lon', 'lat', 'bot-fc', 'bot-usda', 'bot-wp', 'bot-ssks', 'bot-sat', 'bot-ksat', 'bot-name', 'top-fc', 'top-usda', 'top-wp', 'top-ssks', 'top-sat', 'top-ksat', 'top-name', 'soilname'])
    for lon in np.arange(-124.848974, -66.885444, 1/12.):
        print lon
        for lat in np.arange(24.396308, 49.384358, 1/12.):
            props = hwsd.getll(lat, lon)
            if props is None:
                continue
            writer.writerow([lon, lat, props['bot']['fc'], props['bot']['usda'], props['bot']['wp'], props['bot']['ssks'], props['bot']['sat'], props['bot']['ksat'], props['bot']['name'], props['top']['fc'], props['top']['usda'], props['top']['wp'], props['top']['ssks'], props['top']['sat'], props['top']['ksat'], props['top']['name'], props['soilname']])

