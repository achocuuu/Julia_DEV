using ODBC
using DataFrames
using Dates
include("C:\\Users\\jaime.valenzuela\\Documents\\Julia_Scripts\\BoostrappingPrototype\\timeFunc.jl")
include("C:\\Users\\jaime.valenzuela\\Documents\\Julia_Scripts\\BoostrappingPrototype\\timeFunctions.jl")
include("C:\\Users\\jaime.valenzuela\\Documents\\Julia_Scripts\\BoostrappingPrototype\\discountFactor.jl")
include("C:\\Users\\jaime.valenzuela\\Documents\\Julia_Scripts\\BoostrappingPrototype\\functionAux.jl")
include("C:\\Users\\jaime.valenzuela\\Documents\\Julia_Scripts\\BoostrappingPrototype\\curveFunctions.jl")
include("C:\\Users\\jaime.valenzuela\\Documents\\Julia_Scripts\\BoostrappingPrototype\\InstrumentDiscountFactor.jl")
f_val = Dates.Date(2020,05,19)

db = ODBC.Connection("DRIVER={SQL Server};SERVER=VMTDBDEVELO;DATABASE=Riesgo;Trusted_Connection=Yes;")

query = """select
     Instrumento as instrumento
      ,PrecioSucio as precioSucioMD
      ,Rendimiento as rendimiento
      , DiasVenc as diasxVencerMD
      , tasaCupon
      from valmer.Vector
      where Emisora = 'UDIBONO' and fecha = '20200519' and TipoValor = 'S'
      and left(serie,2) <> 23
order by DiasVenc"""

data =  DBInterface.execute(db,query) |> DataFrame  # .query(db, query)

ODBC.disconnect!(db)

data["fechaVencimiento"] = f_val + Dates.Day.(data.diasxVencerMD[:])


plazo = data.diasxVencerMD[1]
fechaFin = data.fechaVencimiento[1]
tasa = data.tasaCupon[1]
paymentsFl = payments(SemiAnnual(),f_val,fechaFin)

function InstrumentFlow(::Bond,dCountConv::DayCountConv,fechaProyeccion::Date,fechaResta::Date,fechaFin::Date,Rate::Float64,payments::Int64,paymentFreq::yieldConvention,notional::Float64,calendario::calendar)
    fechasIni = Array{Date,2}(undef,payments,1)
    fechasFin = Array{Date,2}(undef,payments,1)
    flujo = Array{Float64,2}(undef,payments,1)
    fechasIni[1] = fechaProyeccion
    for i = 1:payments-1
        fechasFin[i] = shiftDate(shiftDay(fechaProyeccion,paymentFreq,i,calendario))
        fechasIni[i+1] = fechasFin[i]
        flujo[i] = notional * Rate * dayCountFactor(dCountConv,fechasIni[i],fechasFin[i])
    end
    fechasFin[payments] = shiftDate(fechaFin)
    flujo[payments] = notional + notional * Rate * dayCountFactor(dCountConv,fechasIni[payments],fechasFin[payments])
    plazoVector = Dates.value.(fechasFin[:] - fechaResta)

    return plazoVector, flujo
end



plazoVector, flujo = InstrumentFlow(Bond(),ACT360(),f_val,f_val,fechaFin,tasa,paymentsFl,SemiAnnual(),1.0,cMXN())
indexDF = findall(x->x==plazoVector[paymentsFl], plazo)[1][1]
obj = 1.0
dfactor[indexDF] = falsePosition(Bond(),ACT360(),fechaTN,fechaTN,fechaFin,tasa,paymentsFl,Annual(),notional,dfactor,plazo,obj,indexDF)
