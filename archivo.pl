% ==============================================================================
% PROYECTO INTEGRADOR - STAR WARS
% FASE I: INGESTA DINÁMICA Y NORMALIZACIÓN DE DATOS
% ==============================================================================

% Librería sugerida por la cátedra para parsear JSON
:- use_module(library(http/json)).

% Declaración estricta de las firmas dinámicas para guardar en memoria
:- dynamic personaje/1.
:- dynamic aparece_en/3.
:- dynamic relacion/5.

% Predicado principal que pide la consigna
inicializar_sistema :-
    % 1. Limpiamos la memoria para evitar datos duplicados si se ejecuta más de una vez (Idempotencia)
    retractall(personaje(_)),
    retractall(aparece_en(_,_,_)),
    retractall(relacion(_,_,_,_,_)),

    % 2. Carga de todos los episodios (1 al 7) y la saga completa.
    % Los archivos JSON están en la carpeta '../archive/' relativa a este .pl

    % --- Episodio 1 ---
    cargar_json('../archive/starwars-episode-1-interactions.json', 1, habla_pura),
    cargar_json('../archive/starwars-episode-1-mentions.json', 1, mencion),
    cargar_json('../archive/starwars-episode-1-interactions-allCharacters.json', 1, interaccion_completa),

    % --- Episodio 2 ---
    cargar_json('../archive/starwars-episode-2-interactions.json', 2, habla_pura),
    cargar_json('../archive/starwars-episode-2-mentions.json', 2, mencion),
    cargar_json('../archive/starwars-episode-2-interactions-allCharacters.json', 2, interaccion_completa),

    % --- Episodio 3 ---
    cargar_json('../archive/starwars-episode-3-interactions.json', 3, habla_pura),
    cargar_json('../archive/starwars-episode-3-mentions.json', 3, mencion),
    cargar_json('../archive/starwars-episode-3-interactions-allCharacters.json', 3, interaccion_completa),

    % --- Episodio 4 ---
    cargar_json('../archive/starwars-episode-4-interactions.json', 4, habla_pura),
    cargar_json('../archive/starwars-episode-4-mentions.json', 4, mencion),
    cargar_json('../archive/starwars-episode-4-interactions-allCharacters.json', 4, interaccion_completa),

    % --- Episodio 5 ---
    cargar_json('../archive/starwars-episode-5-interactions.json', 5, habla_pura),
    cargar_json('../archive/starwars-episode-5-mentions.json', 5, mencion),
    cargar_json('../archive/starwars-episode-5-interactions-allCharacters.json', 5, interaccion_completa),

    % --- Episodio 6 ---
    cargar_json('../archive/starwars-episode-6-interactions.json', 6, habla_pura),
    cargar_json('../archive/starwars-episode-6-mentions.json', 6, mencion),
    cargar_json('../archive/starwars-episode-6-interactions-allCharacters.json', 6, interaccion_completa),

    % --- Episodio 7 ---
    cargar_json('../archive/starwars-episode-7-interactions.json', 7, habla_pura),
    cargar_json('../archive/starwars-episode-7-mentions.json', 7, mencion),
    cargar_json('../archive/starwars-episode-7-interactions-allCharacters.json', 7, interaccion_completa),

    % --- Saga Completa (contexto: saga_completa) ---
    cargar_json('../archive/starwars-full-interactions.json', saga_completa, habla_pura),
    cargar_json('../archive/starwars-full-mentions.json', saga_completa, mencion),
    cargar_json('../archive/starwars-full-interactions-allCharacters.json', saga_completa, interaccion_completa),
    cargar_json('../archive/starwars-full-interactions-allCharacters-merged.json', saga_completa, interaccion_completa),

    write('Todos los datos fueron cargados en memoria exitosamente.'), nl.

% ------------------------------------------------------------------------------
% Predicados Auxiliares de Lectura e Inserción
% ------------------------------------------------------------------------------

% cargar_json(+RutaArchivo, +Contexto, +Tipo)
% Automatiza el abrir, parsear y cerrar el flujo de datos.
cargar_json(Ruta, Contexto, Tipo) :-
    open(Ruta, read, Stream),
    json_read_dict(Stream, Dict),
    close(Stream),
    procesar_diccionario(Dict, Contexto, Tipo).

% procesar_diccionario(+Dict, +Contexto, +Tipo)
% Navega el JSON y realiza los assertz en memoria usando índices explícitos con between/3.
% between(+Low, +High, ?X) genera enteros de Low a High — equivale a un "for i = 0 to N-1".
procesar_diccionario(Dict, Contexto, Tipo) :-

    % 1. Extraer e insertar Nodos (Personajes) usando between para iterar por índice
    length(Dict.nodes, CantNodos),
    MaxNodo is CantNodos - 1,
    forall(
        between(0, MaxNodo, I),
        (
            nth0(I, Dict.nodes, Nodo),
            % Si el personaje no existe en el catálogo global, lo agregamos
            (\+ personaje(Nodo.name) -> assertz(personaje(Nodo.name)) ; true),
            % Agregamos la aparición en este contexto particular (sin duplicados)
            (\+ aparece_en(Nodo.name, Contexto, Tipo) -> assertz(aparece_en(Nodo.name, Contexto, Tipo)) ; true)
        )
    ),

    % 2. Extraer e insertar Links (Relaciones) usando between para iterar por índice
    length(Dict.links, CantLinks),
    MaxLink is CantLinks - 1,
    forall(
        between(0, MaxLink, J),
        (
            nth0(J, Dict.links, Link),
            % Los campos source/target del JSON ya son índices numéricos → resolvemos con nth0
            nth0(Link.source, Dict.nodes, NodoOrigen),
            nth0(Link.target, Dict.nodes, NodoDestino),
            % Inserción del arco dirigido en el grafo social
            assertz(relacion(Tipo, NodoOrigen.name, NodoDestino.name, Link.value, Contexto))
        )
    ).

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
    format("~n"),
    format("+----------------------------------------------------+~n"),
    format("| Contexto: ~w  |  Tipo: ~w~n", [Contexto, Tipo]),
    format("+----------------------------------------------------+~n"),
    format("| ~w~t~50|~n", ['PERSONAJE']),
    format("+----------------------------------------------------+~n"),
    % Contador mutable: término con un argumento, inicializado en 0
    Contador = counter(0),
    % Bucle por falla: itera SIN acumular puntos de elección en el stack
    (   aparece_en(Nombre, Contexto, Tipo),
        format("| ~w~t~50|~n", [Nombre]),
        % Incrementar el contador de forma no retractable (nb_setarg)
        arg(1, Contador, N),
        N1 is N + 1,
        nb_setarg(1, Contador, N1),
        fail                          % fuerza backtracking para seguir iterando
    ;   true                          % cuando no hay más soluciones, continúa acá
    ),
    format("+----------------------------------------------------+~n"),
    arg(1, Contador, Total),
    format("| Total: ~w personajes~n", [Total]),
    format("+----------------------------------------------------+~n").

% ------------------------------------------------------------------------------
% mostrar_relaciones(+Tipo, +Contexto, +PesoMinimo)
%
% Muestra una tabla formateada de relaciones filtradas por tipo, contexto y
% peso mínimo. Usa bucle por falla y nb_setarg para el contador.
% ------------------------------------------------------------------------------
mostrar_relaciones(Tipo, Contexto, PesoMinimo) :-
    format("~n"),
    format("+------------------------+------------------------+-------+~n"),
    format("| Tipo: ~w | Contexto: ~w | Peso >= ~w~n", [Tipo, Contexto, PesoMinimo]),
    format("+------------------------+------------------------+-------+~n"),
    format("| ~w~t~24|| ~w~t~24|| ~w~t~7|~n", ['ORIGEN', 'DESTINO', 'PESO']),
    format("+------------------------+------------------------+-------+~n"),
    Contador = counter(0),
    (   relacion(Tipo, Origen, Destino, Peso, Contexto),
        Peso >= PesoMinimo,
        format("| ~w~t~24|| ~w~t~24|| ~d~t~7|~n", [Origen, Destino, Peso]),
        arg(1, Contador, N),
        N1 is N + 1,
        nb_setarg(1, Contador, N1),
        fail
    ;   true
    ),
    format("+------------------------+------------------------+-------+~n"),
    arg(1, Contador, Total),
    format("| Total: ~w relaciones~n", [Total]),
    format("+------------------------+------------------------+-------+~n").