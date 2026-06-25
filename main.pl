% ==============================================================================
% PROYECTO INTEGRADOR - STAR WARS
% FASE I: INGESTA DINÁMICA Y NORMALIZACIÓN DE DATOS
% ==============================================================================

% Librería sugerida por la cátedra para parsear JSON
:- use_module(tools).

% Predicado principal que pide la consigna
inicializar_sistema :-
    % 1. Limpiamos la memoria para evitar datos duplicados si se ejecuta m�s de una vez (Idempotencia)
    retractall(personaje(_)),
    retractall(aparece_en(_,_,_)),
    retractall(relacion(_,_,_,_,_)),
    % 2. Carga de todos los episodios (1 al 7) y la saga completa.
    descargar_zip,
    listar_archivos_zip,

    write('Todos los datos fueron cargados en memoria exitosamente.'), nl.


% ==============================================================================
% FASE II: MOTOR DE CONSULTAS E INFERENCIA
% ==============================================================================

% ------------------------------------------------------------------------------
% 1. personaje_silencioso(+Nombre, +Episodio) o (-Nombre, +Episodio)
%
% Detecta "Nodos Fantasma": personajes que aparecen en la red extendida
% (interaccion_completa) de un episodio pero no tienen ningún arco
% (ni como origen ni como destino) en la red de habla pura del mismo episodio.
% ------------------------------------------------------------------------------
personaje_silencioso(Nombre, Episodio) :-
    aparece_en(Nombre, Episodio, interaccion_completa),
    \+ relacion(habla_pura, Nombre, _, _, Episodio),
    \+ relacion(habla_pura, _, Nombre, _, Episodio).

% ------------------------------------------------------------------------------
% 2. triangulacion_comunicacion(-PersonajeA, -PersonajeB, +Intermediario, +Episodio)
%
% Encuentra pares de personajes (A, B) que jamás hablaron entre sí (habla_pura)
% en el episodio dado, pero que ambos sí hablaron con el Intermediario.
% La condición A @< B evita respuestas espejo (A,B) y (B,A).
% ------------------------------------------------------------------------------
triangulacion_comunicacion(PersonajeA, PersonajeB, Intermediario, Episodio) :-
    % El intermediario debe existir en ese episodio
    aparece_en(Intermediario, Episodio, habla_pura),
    % A habló con el intermediario (en cualquier dirección)
    (relacion(habla_pura, PersonajeA, Intermediario, _, Episodio) ;
     relacion(habla_pura, Intermediario, PersonajeA, _, Episodio)),
    % B habló con el intermediario (en cualquier dirección)
    (relacion(habla_pura, PersonajeB, Intermediario, _, Episodio) ;
     relacion(habla_pura, Intermediario, PersonajeB, _, Episodio)),
    % A y B son distintos entre sí y distintos del intermediario
    PersonajeA \= PersonajeB,
    PersonajeA \= Intermediario,
    PersonajeB \= Intermediario,
    % Optimización posicional: evita duplicados espejo (A,B) y (B,A)
    PersonajeA @< PersonajeB,
    % A y B NUNCA hablaron directamente entre sí (en ninguna dirección)
    \+ relacion(habla_pura, PersonajeA, PersonajeB, _, Episodio),
    \+ relacion(habla_pura, PersonajeB, PersonajeA, _, Episodio).

% ------------------------------------------------------------------------------
% 3. nucleo_persistente_trilogia_original(-Personaje1, -Personaje2)
%
% Devuelve pares de personajes que mantuvieron relación activa (habla_pura)
% en los tres episodios de la trilogía clásica: IV, V y VI simultáneamente.
% Optimización posicional: Personaje1 @< Personaje2 para evitar respuestas espejo.
% ------------------------------------------------------------------------------
nucleo_persistente_trilogia_original(Personaje1, Personaje2) :-
    % Relación activa en Episodio IV
    (relacion(habla_pura, Personaje1, Personaje2, _, 4) ;
     relacion(habla_pura, Personaje2, Personaje1, _, 4)),
    % Relación activa en Episodio V
    (relacion(habla_pura, Personaje1, Personaje2, _, 5) ;
     relacion(habla_pura, Personaje2, Personaje1, _, 5)),
    % Relación activa en Episodio VI
    (relacion(habla_pura, Personaje1, Personaje2, _, 6) ;
     relacion(habla_pura, Personaje2, Personaje1, _, 6)),
    % Optimización posicional: evita respuestas espejo
    Personaje1 @< Personaje2.

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
    % Contador mutable: término con un argumento, inicializado en 0
    Contador = counter(0),
    % Bucle por falla: itera SIN acumular puntos de elección en el stack
    (   aparece_en(Nombre, Contexto, Tipo),
        format("| ~w~t~53||~n", [Nombre]),
        % Incrementar el contador de forma no retractable (nb_setarg)
        arg(1, Contador, N),
        N1 is N + 1,
        nb_setarg(1, Contador, N1),
        fail                          % fuerza backtracking para seguir iterando
    ;   true                          % cuando no hay más soluciones, continúa acá
    ),
    format("+----------------------------------------------------+~n"),
    arg(1, Contador, Total),
    format("| Total: ~w personajes~t~53||~n", [Total]),
    format("+----------------------------------------------------+~n").

% ------------------------------------------------------------------------------
% mostrar_relaciones(+Tipo, +Contexto, +PesoMinimo)
%
% Muestra una tabla formateada de relaciones filtradas por tipo, contexto y
% peso mínimo. Usa bucle por falla y nb_setarg para el contador.
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
