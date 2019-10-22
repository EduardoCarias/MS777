using ExcelReaders, JuMP, Dates

function getDispCrianca(C::Array{Any,2}, D::Array{Any,2}, H::Array{Any,2})

    f = openxl(joinpath(@__DIR__,"modelo-de-dados-ccp.xlsx"));
    #Horários de manhã
    h1 = readxl(f, "Auxiliar!F2:F11");
    #Horários de tarde
    h2 = readxl(f, "Auxiliar!F12:F20");

    disponibilidade = JuMP.Containers.DenseAxisArray{Int64}(undef, C, D, H);
    fill!(disponibilidade, zero(Int64));
    #Disponibilidade da criança
    dispExcel = readxl(f, "Disponibilidade da Criança!A2:E81");

    for i = 1:length(dispExcel[:,1])
       crianca = dispExcel[i,1]
       dia = dispExcel[i,2];
       peri = dispExcel[i,3];
       ini = dispExcel[i,4];
       fim = dispExcel[i,5];

        if peri == "Manhã"
           if dia == "Todos"
               for d in D, h in h1
                   disponibilidade[crianca,d,h] = 1;
               end
           else
               for h in h1
                   disponibilidade[crianca,dia,h1] = 1;
               end
           end
       elseif peri == "Tarde"
           if dia == "Todos"
               for d in D, h in h2
                   disponibilidade[crianca,d,h] = 1;
                end
            else
                for h in h2
                    disponibilidade[crianca,dia,h] = 1;
                end
            end
        elseif peri == "Ambos"
            if dia == "Todos"
                for d in D, h in H
                    disponibilidade[crianca,d,h] = 1;
                end
            else
                for h in H
                    disponibilidade[crianca,dia,h]
                end
            end
        elseif peri == "Horário"
            if fim >= Dates.Time(12,00,00)
                peri = "Tarde"
            else
                peri = "Manhã"
            end
            if dia == "Todos"
                for d in D, h in H
                    if h >= ini && h <= fim
                        disponibilidade[crianca,d,h] = 1;
                    end
                end
            else
                for h in H
                    if h >= ini && h <= fim
                        disponibilidade[crianca,dia,h] = 1;
                    end
                end
            end
         end
   end

   return disponibilidade;
end
