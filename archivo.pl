% ==============================================================================
% PROYECTO INTEGRADOR - STAR WARS
% FASE I: INGESTA DINÁMICA Y NORMALIZACIÓN DE DATOS
% ==============================================================================

% Librería sugerida por la cátedra para parsear JSON
:- use_module(library(http/json)).
:- use_module(library(http/http_open)).
:- use_module(library(zip)).

% Declaración estricta de las firmas dinámicas para guardar en memoria
:- dynamic personaje/1.
:- dynamic aparece_en/3.
:- dynamic relacion/5.

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

% ------------------------------------------------------------------------------
% Predicados Auxiliares de Descarga, Lectura e Inserción
% ------------------------------------------------------------------------------
%
url_dataset('https://www.kaggle.com/api/v1/datasets/download/ruchi798/star-wars').

descargar_zip :-
    url_dataset(URL),
    setup_call_cleanup(
        http_open(URL, Stream, []),
        setup_call_cleanup(
            open('star-wars.zip', write, Out, [type(binary)]),
            copy_stream_data(Stream, Out),
            close(Out)
        ),
        close(Stream)
    ).


listar_archivos_zip :-
    zip_open('star-wars.zip', read, Zip, []),
    zipper_goto(Zip, first),
    cargar_archivos(Zip),
    zip_close(Zip).

cargar_archivos(Zip):-
    cargar_json_zip(Zip),
    (zipper_goto(Zip, next)
    -> cargar_archivos(Zip)
    ; true).

tipo_archivo(Archivo, habla_pura) :-
    sub_atom(Archivo, _, _, _, "interactions.json").

tipo_archivo(Archivo, mencion) :-
    sub_atom(Archivo, _, _, _, "mentions.json").

tipo_archivo(Archivo, interaccion_completa) :-
    sub_atom(Archivo, _, _, _, "allCharacters").

episode_number(Archivo, Ep):-
    sub_string(Archivo, Pos, _, _, "episode-"),
    Start is Pos + 8,
    sub_string(Archivo, Start, 1, _, Ep).

episode_number(Archivo, saga_completa):-
    sub_string(Archivo, _, _, _, "full").

cargar_json_zip(Zip) :-
    zipper_file_info(Zip, Archivo, _),
    %podriamos controlar sobre tipos "desconocidos"
    tipo_archivo(Archivo, Tipo),
    %podriamos controlar sobre contextos "desconocidos"
    episode_number(Archivo, Contexto),
    zipper_open_current(Zip, Stream, []),
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
