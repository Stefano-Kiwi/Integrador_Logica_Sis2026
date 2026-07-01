% ==============================================================================
% PROYECTO INTEGRADOR - STAR WARS
% FASE I: INGESTA DINÃMICA Y NORMALIZACIÃ“N DE DATOS
% ==============================================================================
% Cambiamos el working directory para luego leer el Zip
:- prolog_load_context(directory, Dir),
   working_directory(_, Dir).
% LibrerÃ­a sugerida por la cÃ¡tedra para parsear JSON
:- use_module(tools).

% Predicado principal que pide la consigna
inicializar_sistema :-
    % 1. Limpiamos la memoria para evitar datos duplicados si se ejecuta mas de una vez (Idempotencia)
    retractall(personaje(_)),
    retractall(aparece_en(_,_,_)),
    retractall(relacion(_,_,_,_,_)),
    % 2. Carga de todos los episodios (1 al 7) y la saga completa.
    %descargar_zip,
    listar_archivos_zip,

    write('Todos los datos fueron cargados en memoria exitosamente.'), nl.


% ==============================================================================
% FASE II: MOTOR DE CONSULTAS E INFERENCIA
% ==============================================================================

% ------------------------------------------------------------------------------
% 1. personaje_silencioso(+Nombre, +Episodio) o (-Nombre, +Episodio)
%
% Detecta "Nodos Fantasma": personajes que aparecen en la red extendida
% (interaccion_completa) de un episodio pero no tienen ningÃºn arco
% (ni como origen ni como destino) en la red de habla pura del mismo episodio.
% ------------------------------------------------------------------------------
personaje_silencioso(Nombre, Episodio) :-
    aparece_en(Nombre, Episodio, interaccion_completa),
    \+ relacion(habla_pura, Nombre, _, _, Episodio),
    \+ relacion(habla_pura, _, Nombre, _, Episodio).

% ------------------------------------------------------------------------------
% 2. triangulacion_comunicacion(-PersonajeA, -PersonajeB, +Intermediario, +Episodio)
%
% Encuentra pares de personajes (A, B) que jamÃ¡s hablaron entre sÃ­ (habla_pura)
% en el episodio dado, pero que ambos sÃ­ hablaron con el Intermediario.
% La condiciÃ³n A @< B evita respuestas espejo (A,B) y (B,A).
% ------------------------------------------------------------------------------
triangulacion_comunicacion(PersonajeA, PersonajeB, Intermediario, Episodio) :-
    % El intermediario debe existir en ese episodio
    aparece_en(Intermediario, Episodio, habla_pura),
    % A hablÃ³ con el intermediario (en cualquier direcciÃ³n)
    (relacion(habla_pura, PersonajeA, Intermediario, _, Episodio) ;
     relacion(habla_pura, Intermediario, PersonajeA, _, Episodio)),
    % B hablÃ³ con el intermediario (en cualquier direcciÃ³n)
    (relacion(habla_pura, PersonajeB, Intermediario, _, Episodio) ;
     relacion(habla_pura, Intermediario, PersonajeB, _, Episodio)),
    % A y B son distintos entre sÃ­ y distintos del intermediario
    PersonajeA \= PersonajeB,
    PersonajeA \= Intermediario,
    PersonajeB \= Intermediario,
    % OptimizaciÃ³n posicional: evita duplicados espejo (A,B) y (B,A)
    PersonajeA @< PersonajeB,
    % A y B NUNCA hablaron directamente entre sÃ­ (en ninguna direcciÃ³n)
    \+ relacion(habla_pura, PersonajeA, PersonajeB, _, Episodio),
    \+ relacion(habla_pura, PersonajeB, PersonajeA, _, Episodio).

% ------------------------------------------------------------------------------
% 3. nucleo_persistente_trilogia_original(?Personaje1, ?Personaje2)
%
% Devuelve pares de personajes que mantuvieron relacion activa (habla_pura)
% en los tres episodios de la trilogia clasica: IV, V y VI simultaneamente.
%
% Modos soportados:
%   - Ambos libres    -> retorna pares canonicos sin duplicados (A @< B)
%   - Alguno ligado   -> busca en ambas direcciones, simetrico
% ------------------------------------------------------------------------------

% Caso 1: ambas variables libres -> pares canonicos sin duplicados (A @< B)
nucleo_persistente_trilogia_original(A, B) :-
    var(A), var(B), !,
    nucleo_base_(A, B).

% Caso 2: alguna variable esta ligada -> busca en ambas direcciones
nucleo_persistente_trilogia_original(P1, P2) :-
    ( nucleo_base_(P1, P2)   % P1 es el menor lexicografico
    ; nucleo_base_(P2, P1)   % P1 es el mayor lexicografico
    ).

% Predicado interno: genera pares canonicos donde A @< B
% y la relacion fue activa en ep4, ep5 y ep6.
nucleo_base_(A, B) :-
    % Generamos A y B desde personajes del ep4, garantizando orden canonico
    aparece_en(A, 4, habla_pura),
    aparece_en(B, 4, habla_pura),
    A @< B,
    % Verificacion en ep4: once evita duplicados por relacion bidireccional
    once((relacion(habla_pura, A, B, _, 4) ; relacion(habla_pura, B, A, _, 4))),
    % Verificacion en ep5
    once((relacion(habla_pura, A, B, _, 5) ; relacion(habla_pura, B, A, _, 5))),
    % Verificacion en ep6
    once((relacion(habla_pura, A, B, _, 6) ; relacion(habla_pura, B, A, _, 6))).

% ==============================================================================
% FASE III: INTERFAZ DE CONSOLA Y FORMATEO VISUAL
% ==============================================================================

% ------------------------------------------------------------------------------
% mostrar_personajes(+Contexto, +Tipo)
%
% Muestra una tabla formateada con todos los personajes de un contexto y tipo.
% Usa bucle por falla (fail) para no saturar el stack.
% Usa nb_setarg para contar registros sin que el backtracking destruya el acumulador.
% ------------------------------------------------------------------------------
mostrar_personajes(Contexto, Tipo) :-
    % Si Tipo es una variable libre, asignamos el texto 'Todos', si no, se queda como esta
    ( var(Tipo)     -> Tipo_Print = 'Todos'    ; Tipo_Print = Tipo ),

    % Si Contexto es una variable libre, asignamos 'Todos', si no, se queda igual
    ( var(Contexto) -> Contexto_Print = 'Todos'; Contexto_Print = Contexto ),
    format("~n"),
    format("+----------------------------------------------------+~n"),
    format("| Contexto: ~w~t  |  Tipo: ~w~t~53||~n", [Contexto_Print, Tipo_Print]),
    format("+----------------------------------------------------+~n"),
    format("| ~w~t~53||~n", ['PERSONAJE']),
    format("+----------------------------------------------------+~n"),
    % Contador mutable: tÃ©rmino con un argumento, inicializado en 0
    Contador = counter(0),
    % Bucle por falla: itera SIN acumular puntos de elecciÃ³n en el stack
    (   aparece_en(Nombre, Contexto, Tipo),
        format("| ~w~t~53||~n", [Nombre]),
        % Incrementar el contador de forma no retractable (nb_setarg)
        arg(1, Contador, N),
        N1 is N + 1,
        nb_setarg(1, Contador, N1),
        fail                          % fuerza backtracking para seguir iterando
    ;   true                          % cuando no hay mas soluciones, continua aca
    ),
    format("+----------------------------------------------------+~n"),
    arg(1, Contador, Total),
    format("| Total: ~w personajes~t~53||~n", [Total]),
    format("+----------------------------------------------------+~n").

% ------------------------------------------------------------------------------
% mostrar_relaciones(+Tipo, +Contexto, +PesoMinimo)
%
% Muestra una tabla formateada de relaciones filtradas por tipo, contexto y
% peso minimo. Usa bucle por falla y nb_setarg para el contador.
% ------------------------------------------------------------------------------
mostrar_relaciones(Tipo, Contexto, PesoMinimo) :-
    % Si Tipo es una variable libre, asignamos el texto 'Todos', si no, se queda como esta
    ( var(Tipo)     -> Tipo_Print = 'Todos'    ; Tipo_Print = Tipo ),

    % Si Contexto es una variable libre, asignamos 'Todos', si no, se queda igual
    ( var(Contexto) -> Contexto_Print = 'Todos'; Contexto_Print = Contexto ),
    format("~n"),
    format("+------------------------+------------------------+-------+~n"),
    format("| Tipo: ~w | Contexto: ~w | Peso >= ~w~t~58||~n", [Tipo_Print, Contexto_Print, PesoMinimo]),
    format("+------------------------+------------------------+-------+~n"),
    format("| ~w~t~25|| ~w~t~50|| ~w~t~58||~n", ['ORIGEN', 'DESTINO', 'PESO']),
    format("+------------------------+------------------------+-------+~n"),
    Contador = counter(0),
    (   relacion(Tipo, Origen, Destino, Peso, Contexto),
        Peso >= PesoMinimo,
        format("| ~w~t~25|| ~w~t~50|| ~d~t~58||~n", [Origen, Destino, Peso]),
        arg(1, Contador, N),
        N1 is N + 1,
        nb_setarg(1, Contador, N1),
        fail
    ;   true
    ),
    format("+------------------------+------------------------+-------+~n"),
    arg(1, Contador, Total),
    format("| Total: ~w relaciones~t~58||~n", [Total]),
    format("+------------------------+------------------------+-------+~n").