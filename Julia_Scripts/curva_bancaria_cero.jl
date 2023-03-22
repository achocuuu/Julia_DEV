using CSV
using Dates
using DataFrames
using DataFramesMeta
using SQLite
using XLSX
import ODBC
import DataFrames
import Query
import DataFramesMeta
include("timeFunc.jl")
include("timeFunctions.jl")
include("discountFactor.jl")
include("functionAux.jl")
include("curveFunctions.jl")
include("InstrumentDiscountFactor.jl")

dnsConn = "VMTDBDEVELO_conn"
sqlString = "declare @fecha_t date = '20200506'

select distinct * from (
select  fecha, 'Cash' as typeRate, 1 as plazo , PrecioSucio/100 as yield, 0.0 as TasaCupon, 0.0 as PrecioSucio
from valmer.Vector where fecha = @fecha_t and TipoValor = 'TR'
and emisora = 'TFD1' --and TipoValor = 'BI'
union all
select fecha,'Cash' as typeRate, DiasVenc as plazo, rendimiento/100 as yield , 0.0 as TasaCupon, 0.0 as PrecioSucio
from Valmer.Vector
where fecha = @fecha_t and EMISORA = 'CETES' and tipovalor = 'BI' and DiasVenc <= 360
union all
select fecha,'Bond' as typeRate, DiasVenc as plazo, rendimiento/100 as yield , TasaCupon, PrecioSucio
from Valmer.Vector
where fecha = @fecha_t and left(Instrumento,7) = 'M_BONOS' and DiasVenc > 360
) as tmp
order by plazo"

conn = ODBC.DSN(dnsConn)
fechaStrHoy = "20200506"#una forma de refactorizar esto es que sea un vector de fechas que vaya desde t hasta settlement date
fechaHoy = Date(fechaStrHoy, DateFormat("yyyymmdd"))
dataCurve = ODBC.query(conn,sqlString)
plazo = convert.(Int64,dataCurve.plazo[:])
plazo =  reshape(plazo,length(plazo),1)
dfactor = Array{Float64,2}(undef, length(dataCurve[:,1]), 1)

dfactor[1:end] .= 1.0
#overnight
dfactor[1] = df(Linear(),dayCountFactor(ACT360(),fechaHoy,fechaHoy+Dates.Day(1)),dataCurve.yield[1])
stIdx = minimum(findall(x->x=="Cash", dataCurve.typeRate)[:])
endIdx = maximum(findall(x->x=="Cash", dataCurve.typeRate)[:])
dfactor[stIdx:endIdx] = df.(Linear.(),dayCountFactor.(ACT360.(),fechaHoy,fechaHoy+Dates.Day.(dataCurve.plazo[stIdx:endIdx])),dataCurve.yield[stIdx:endIdx])


stIdx = minimum(findall(x->x=="Bond", dataCurve.typeRate)[:])
endIdx = maximum(findall(x->x=="Bond", dataCurve.typeRate)[:])
# for i =2:length(plazo)
i=stIdx
notional = 1.0
fechaFin = fechaHoy + Dates.Day(dataCurve.plazo[i])
tasa = dataCurve.TasaCupon[i]
paymentsFl = payments(SemiAnnual(),fechaHoy,fechaFin)
plazoVector, flujo = InstrumentFlow(Bond(),ACT360(),fechaHoy,fechaHoy,fechaFin,tasa,paymentsFl,SemiAnnual(),notional,cMXN())
indexDF = findall(x->x==plazoVector[paymentsFl], plazo)[1][1]
obj = dataCurve.PrecioSucio[i]/100
dfactor[indexDF] =  falsePosition(Bond(),ACT360(),fechaHoy,fechaHoy,fechaFin,tasa,paymentsFl,SemiAnnual(),notional,dfactor,plazo,obj,indexDF,cMXN())
# end

print(dfa)
