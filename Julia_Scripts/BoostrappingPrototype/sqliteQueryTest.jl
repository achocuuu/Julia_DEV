

using SQLite
using DataFrames

db = SQLite.DB("C:\\Users\\jaime.valenzuela\\Documents\\sqlitedb.db")

SQLite.Query(db, "select * from curveDef where curveName = 'CLPCAMARA'") |> DataFrame
