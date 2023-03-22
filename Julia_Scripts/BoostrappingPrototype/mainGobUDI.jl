using CSV
using Dates
using DataFrames
using DataFramesMeta
using SQLite
include("bootsFunc.jl")
include("timeFunc.jl")

##################################load Data#############################################
#Tasas:
path = "C:\\Users\\jaime.valenzuela\\Documents\\Julia_Scripts\\BoostrappingPrototype\\bidaskGOBIERNOUDI.csv"
dataMktRate = CSV.read(path)
#Obtener mid, ask o bid
rates = dataMktRate[:, filter(x -> (x in [:tenor, :mid]), names(dataMktRate))]
rates.mid = rates.mid / 100

#Definiciones de curva
db = SQLite.DB("C:\\Users\\jaime.valenzuela\\Documents\\sqlitedb.db")
dataCurve = SQLite.Query(db,"select * from curveDef where curveName = 'GOBIERNO.UDI'",
) |> DataFrame
curveInfo = SQLite.Query(db, "select * from curveInfo where name = 'GOBIERNO.UDI'") |> DataFrame

#Definiciones
notional = 1.0
fechaStrHoy = "20200131"
sett = curveInfo.settlement[1] #una forma de refactorizar esto es que sea un vector de fechas que vaya desde t hasta settlement date
fechaHoy = Date(fechaStrHoy, DateFormat("yyyymmdd"))
fechaON = shiftDate(fechaHoy + Dates.Day(max(1)))
fechaTN = shiftDate(fechaHoy + Dates.Day(sett))
payFreq = curveInfo.payFreq[1]
calendar = "MXN"

curva = curveInit(dataCurve,fechaHoy,fechaON,fechaTN, payFreq, calendar)

showall(curva)

#Obtener curva
curve = curva[:, filter(x -> (x in [:tenor, :days, :df]), names(curva))]
tenorsBoots = curva[in.(curva.tipo, Ref(["Bond/Swap rate"])), :tenor]
paysInYear = 2
periodicidadMensual = 6

for i = 1:length(tenorsBoots)
    tenorSwap = tenorsBoots[i]
    payments = convert(Int, tenorMonths(tenorSwap) / 12 * paysInYear)
    flowtest = fixFlow(curve,paysInYear,fechaTN,periodicidadMensual,tenorSwap, rates)
    falsePosition(curve,tenorSwap,flowtest, payments)
end

showall(curve)
