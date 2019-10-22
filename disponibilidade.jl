include(joinpath(@__DIR__,"disponibilidadeCriancas.jl"))
include(joinpath(@__DIR__,"disponibilidadeProfissionais.jl"))

using ExcelReaders, JuMP, Dates


function getDisponibilidade(C::Array{Any,2}, M::Array{String,1}, H::Array{Any,2}, D::Array{Any,2})

    disponibilidadeCrianca = getDispCrianca(C,D,H);
    disponibilidadeProfissional = getDispProfissional(M,D,H);

    disponibilidade = JuMP.Containers.DenseAxisArray{Int64}(undef, C, M, H, D);
    fill!(disponibilidade, false);

    for c in C, m in M, d in D, h in H
        if disponibilidadeProfissional[m,d,h] == disponibilidadeCrianca[c,d,h]
            disponibilidade[c,m,h,d] = true;
        end
    end

    return disponibilidade
end
