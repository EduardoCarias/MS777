using Dates, JuMP, Gurobi, ExcelReaders

const GRB_ENV = Gurobi.Env()

const BigM = 1000

include(joinpath(@__DIR__, "disponibilidade.jl"))
include(joinpath(@__DIR__, "demanda.jl"))

function modeloCCP()
    CCP = Model(with_optimizer(Gurobi.Optimizer, GRB_ENV))
    setparams!(GRB_ENV, TimeLimit=2000, MIPGap=0.05)

    # DADOS INICIAIS
    # Indices e Variáveis ------------------------------------------------------
    println("Inicializando indices e variáveis")
    f = openxl(joinpath(@__DIR__,"modelo-de-dados-ccp.xlsx"))
    # Conjuntos:
    #Crianças
    C = readxl(f, "Cadastro da Criança!A2:A81");
    #Profissionais
    M = ["Vitória", "Helena", "César",
        "Vinicius", "Amanda", "Isadora"];
    #Especialidades
    E = ["Fisioterapia", "Fonoaudiologia", "Pedagogia",
        "Terapia Ocupacional", "Neurologia", "Nutrição"];
    #Horários
    H = readxl(f, "Auxiliar!F2:F20");
    #Dias
    D = readxl(f, "Auxiliar!C2:C6");
    #Conjuntos de dias auxiliares para restrições de intervalo de atendimento
    DSemSegunda = readxl(f, "Auxiliar!C3:C6");
    DSemSexta = readxl(f, "Auxiliar!C2:C5");
    #Períodos
    P = ["Manhã", "Tarde"];
    # Atendimento da crianca c pelo profissional m no periodo p, hora h, dia d
    @variable(CCP, atendimentos[c in C, m in M, h in H, d in D], Bin);
    # Binária que indica se houve atendimento de tarde no dia para a criança
    @variable(CCP, atendeDeTarde[c in C, d in D], Bin);
    # Binária que indica se houve atendimento da especialidade no dia para a criança
    @variable(CCP, atendeHoje[c in C, d in D, e in E], Bin);
    #---------------------------------------------------------------------------
    println("Calculando Parâmetros");
    # Parâmetros ---------------------------------------------------------------
    # Domínio de disponibilidade do dia e horário
    disponivel = getDisponibilidade(C,M,H,D);
    #Demanda das criancas por especialidade
    demanda = getDemanda(C,E);
    # Mapeamento de profissional para especialidade
    medicoEspecialidade = JuMP.Containers.DenseAxisArray{Bool}(undef, M, E);
    fill!(medicoEspecialidade, false);
    for m in M
        planilha = m*"!A1"
        e = readxl(f, planilha);
        medicoEspecialidade[m,e] = true;
    end
    # Mapeamento de horário para período
    horarioDoPeriodo = JuMP.Containers.DenseAxisArray{Bool}(undef, H, P)
    fill!(horarioDoPeriodo, false);
    for h in H
        if h >= Dates.Time(12,00,00)
            horarioDoPeriodo[h,P[2]] = true;
        else
            horarioDoPeriodo[h,P[1]] = true;
        end
    end
    # Mapeamento de dia para inteiro e vice-versa
    getDia = Dict{Int64,String}();
    indiceDia = Dict{String,Int64}();
    for i in 1:5
        push!(getDia, i => D[i])
        push!(indiceDia, D[i] => i)
    end
    # Mapeamento de horário para inteiro
    indiceHorario = Dict{Dates.Time,Int64}();
    for i in 1:19
        push!(indiceHorario, H[i] => i)
    end
    #---------------------------------------------------------------------------

    #RESTRIÇÕES
    # Não pode atender se não estiver disponível -------------------------------
    @constraint(CCP, atendIndisponivel,
        sum(atendimentos[c,m,h,d] for c in C, m in M, h in H, d in D
            if disponivel[c,m,h,d] == 0)
        ==
        0
    );
    # --------------------------------------------------------------------------
    # Atendimento de demanda da criança por especialidade ----------------------
    @constraint(CCP, atendDemanda[c in C, e in E],
        sum(atendimentos[c,m,h,d] for d in D, h in H, m in M
            if (medicoEspecialidade[m,e] && disponivel[c,m,h,d] == 1))
        <=
        demanda[c,e]
    );
    # --------------------------------------------------------------------------
    # Só uma criança pode ser atendida de cada vez -----------------------------
    @constraint(CCP, umaCriancaPorAtend[m in M, d in D, h in H],
        sum(atendimentos[c,m,h,d] for c in C if disponivel[c,m,h,d] == 1)
        <=
        1
    );
    # --------------------------------------------------------------------------
    # Crianca não pode estar em dois atendimentos no mesmo horário -------------
    @constraint(CCP, umHorarioPorCrianca[c in C, d in D, h in H],
        sum(atendimentos[c,m,h,d] for m in M if disponivel[c,m,h,d] == 1)
        <=
        1
    );
    # --------------------------------------------------------------------------
    # Atendimento em apenas um período do dia ----------------------------------
    @constraint(CCP, periodosDiferentesTarde[c in C, d in D],
        sum(atendimentos[c,m,h,d] for h in H, m in M
            if (horarioDoPeriodo[h,P[2]] && disponivel[c,m,h,d] == 1))
        <=
        atendeDeTarde[c,d]*BigM
    );

    @constraint(CCP, periodosDiferentesManha[c in C, d in D],
        sum(atendimentos[c,m,h,d] for h in H, m in M
            if (horarioDoPeriodo[h,P[1]] && disponivel[c,m,h,d] == 1))
        <=
        (1-atendeDeTarde[c,d])*BigM
    );
    #---------------------------------------------------------------------------
    # Intervalo de um dia de atendimento para a mesma especialidade ------------
    @constraint(CCP, atendimentoHoje[c in C, d in D, e in E],
        sum(atendimentos[c,m,h,d] for h in H, m in M
            if medicoEspecialidade[m,e] && disponivel[c,m,h,d] == 1)
        <=
        atendeHoje[c,d,e]*BigM
    );

    @constraint(CCP, atendimentoOntem[c in C, d in DSemSegunda, e in E],
        sum(atendimentos[c,m,h,d] for h in H, m in M
            if (medicoEspecialidade[m,e] && disponivel[c,m,h,d] == 1))
        <=
        atendeHoje[c,getDia[indiceDia[d]-1],e]*BigM
    );

    @constraint(CCP, atendimentoAmanha[c in C, d in DSemSexta, e in E],
        sum(atendimentos[c,m,h,d] for h in H, m in M
            if (medicoEspecialidade[m,e] && disponivel[c,m,h,d] == 1))
        <=
        atendeHoje[c,getDia[indiceDia[d]+1],e]*BigM
    );
    #---------------------------------------------------------------------------
    # FUNÇÃO OBJETIVO
    funcaoObjetivo = @expression(CCP,
        sum(atendimentos[c,m,h,d] for c in C, m in M, h in H, d in D));

    @objective(CCP, Max, funcaoObjetivo);
    println("Otimizando")
    optimize!(CCP)

end
