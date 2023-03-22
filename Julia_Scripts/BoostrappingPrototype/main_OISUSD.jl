using CSV
using Dates
using DataFrames
using DataFramesMeta
using SQLite
using XLSX
include("bootsFunc.jl")
include("timeFunc.jl")

##################################load Data#############################################
#Tasas (proveedor):
path = "C:\\Users\\jaime.valenzuela\\Documents\\Julia_Scripts\\BoostrappingPrototype\\bidaskOIS.csv"
dataMktRate = CSV.read(path)
#Obtener mid, ask o bid
rates = dataMktRate[:, filter(x -> (x in [:tenor, :mid]), names(dataMktRate))]
rates.mid = rates.mid

#Definiciones de curva
db = SQLite.DB("C:\\Users\\jaime.valenzuela\\Documents\\sqlitedb.db")
dataCurve = SQLite.Query(db,"select * from curveDef where curveName = 'OIS USD'",
) |> DataFrame
curveInfo = SQLite.Query(db, "select * from curveInfo where id_curve = 3") |> DataFrame

#Definiciones
notional = 1.0
fechaStrHoy = "20200131"
sett = curveInfo.settlement[1] #una forma de refactorizar esto es que sea un vector de fechas que vaya desde t hasta settlement date
fechaHoy = Date(fechaStrHoy, DateFormat("yyyymmdd"))
fechaON = shiftDate(fechaHoy + Dates.Day(1))
fechaTN = shiftDate(fechaON + Dates.Day(1))
payFreq = curveInfo.payFreq[1]
Calendario = "US"
curva = curveInit(dataCurve,fechaHoy,fechaON,fechaTN)

#Obtener curva:
curve = curva[:, filter(x -> (x in [:tenor, :days, :df]), names(curva))]
tenorsBoots = curva[in.(curva.tipo, Ref(["Swap Rate"])), :tenor]
paysInYear = 1
periodicidadMensual = 12
#Boostrapping:
for i = 1:length(tenorsBoots)
    tenorSwap = tenorsBoots[i]
    payments = convert(Int, ceil(tenorMonths(tenorSwap)/ 12)  * paysInYear)
    flowtest = fixFlow(curve,paysInYear,fechaTN,periodicidadMensual,tenorSwap, rates)
    falsePosition(curve,tenorSwap,flowtest, payments)
end

#Si no hay TN esto no es necesario
curvaFinal = curveFinal(dataCurve,fechaHoy,fechaON,fechaTN)
dfFinal = curve.df
#update
curva.df = curve.df

curvaFinal.df[3:end] = curve.df[3:end]*curve.df[2]

XLSX.writetable(string(fechaStrHoy, " ",curveInfo.name[1] , " Curva.xlsx"),
                    curva_t = (collect(DataFrames.eachcol(curvaFinal)),collect(DataFrames.names(curvaFinal))),
                    curva_settlement = (collect(DataFrames.eachcol(curva)),collect(DataFrames.names(curva)))
)
