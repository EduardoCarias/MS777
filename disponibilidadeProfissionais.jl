using ExcelReaders, JuMP, Dates

function getDispProfissional(M::Array{String,1}, D::Array{Any,2}, H::Array{Any,2})
    f = openxl(joinpath(@__DIR__,"modelo-de-dados-ccp.xlsx"));
    #Horários de manhã
    h1 = readxl(f, "Auxiliar!F2:F11");
    #Horários de tarde
    h2 = readxl(f, "Auxiliar!F12:F20");
    disponibilidade = JuMP.Containers.DenseAxisArray{Int64}(undef, M, D, H);
    fill!(disponibilidade, zero(Int64));

    mapDias = Dict{Int64,String}();
    for i in 2:6
        push!(mapDias, i => D[i-1])
    end

    for m in M
        sheet = m*"!A2:F20";
        grade = readxl(f, sheet);
        for h = 1:19
            hora = grade[h,1]
            for d = 2:6
                if grade[h,d] != "Indisponível"
                    disponibilidade[m,mapDias[d],hora] = 1;
                end
            end
        end
    end

    return disponibilidade
end
