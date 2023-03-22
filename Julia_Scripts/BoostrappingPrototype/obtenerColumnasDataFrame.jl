#rates = df[:,filter(x -> !(x in [:tenor,:mid]),names(df) )]--eliminar
rates = dataMktRate[:,filter(x -> (x in [:tenor,:mid]),names(df) )]
#rates = df[:,filter(x -> x == :mid ,names(df))]

#eliminar missing values
names!(dataCurveDef,[:Tenor,:mktDesc])
