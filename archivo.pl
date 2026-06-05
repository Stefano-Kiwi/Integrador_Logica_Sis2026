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

    % 2. Carga dinámica de los archivos. 
    % Usamos '../' porque los JSON están una carpeta por fuera del repositorio actual.
    % ATENCIÓN: Revisá que los nombres de los archivos coincidan exactamente con los que descargaste.
    
    % --- Carga del Episodio 4 ---
    cargar_json('../starwars-episode-4-interactions.json', 4, habla_pura),
    cargar_json('../starwars-episode-4-mentions.json', 4, mencion),
    cargar_json('../starwars-episode-4-interactions-allCharacters.json', 4, interaccion_completa),
    
    % --- ACÁ DEBEN AGREGAR LAS LÍNEAS PARA LOS EPISODIOS 1, 2, 3, 5, 6, 7 Y LA SAGA COMPLETA ---
    % Ejemplo para el episodio 5:
    % cargar_json('../starwars-episode-5-interactions.json', 5, habla_pura),
    % cargar_json('../starwars-episode-5-mentions.json', 5, mencion),
    % cargar_json('../starwars-episode-5-interactions-allCharacters.json', 5, interaccion_completa),

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
% Navega el JSON y realiza los assertz en memoria usando el nombre real de los personajes.
procesar_diccionario(Dict, Contexto, Tipo) :-
    
    % 1. Extraer e insertar Nodos (Personajes)
    forall(nth0(_Indice, Dict.nodes, Nodo),
        (
            % Si el personaje no existe en el catálogo global, lo agregamos
            (\+ personaje(Nodo.name) -> assertz(personaje(Nodo.name)) ; true),
            
            % Agregamos la aparición en este contexto particular
            assertz(aparece_en(Nodo.name, Contexto, Tipo))
        )
    ),
    
    % 2. Extraer e insertar Links (Relaciones)
    forall(member(Link, Dict.links), 
        (
            % Mapeo de índice numérico a Nombre de personaje (String/Atomo)
            nth0(Link.source, Dict.nodes, NodoOrigen),
            nth0(Link.target, Dict.nodes, NodoDestino),
            
            % Inserción del arco dirigido en el grafo social
            assertz(relacion(Tipo, NodoOrigen.name, NodoDestino.name, Link.value, Contexto))
        )
    ).

% ==============================================================================
% FASE II: MOTOR DE CONSULTAS E INFERENCIA (Estructura base)
% ==============================================================================
% Acá irán: personaje_silencioso/2, triangulacion_comunicacion/4, nucleo_persistente_trilogia_original/2.


% ==============================================================================
% FASE III: INTERFAZ DE CONSOLA Y FORMATEO VISUAL (Estructura base)
% ==============================================================================
% Acá irán: mostrar_personajes/2, mostrar_relaciones/3.