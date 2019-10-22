using ExcelReaders, JuMP

function getDemanda(C::Array{Any,2},E::Array{String,1})

    f = openxl(joinpath(@__DIR__,"modelo-de-dados-ccp.xlsx"))
    demanda = JuMP.Containers.DenseAxisArray{Int64}(undef, C, E);
    demandaExcel = readxl(f, "Atendimento Regular!A2:E277");
    fill!(demanda, 0);
    for i = 1:length(demandaExcel[:,1])
        crianca = demandaExcel[i,1]
        especialidade = demandaExcel[i,2];
        demanda[crianca,especialidade] = demandaExcel[i,3]
    end

    return demanda;
end;
