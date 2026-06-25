:-module(tools, [
             url_dataset/1,
             descargar_zip/0,
             listar_archivos_zip/0,
             personaje/1,
             aparece_en/3,
             relacion/5
                ]).

%Librería sugerida por la cátedra para parsear JSON
:- use_module(library(http/json)).
:- use_module(library(http/http_open)).
:- use_module(library(zip)).


% Declaración estricta de las firmas dinámicas para guardar en memoria
:- dynamic personaje/1.
:- dynamic aparece_en/3.
:- dynamic relacion/5.

% ------------------------------------------------------------------------------
%Predicados Auxiliares de Descarga, Lectura e Inserción
% ------------------------------------------------------------------------------
%
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
    % Si Contexto se puede transformar en numero, lo hace.
    % Si falla se convierte en un atomo normal.
    (   atom_number(Contexto, Contexto_Atom)
    ->  true
    ;   Contexto_Atom = Contexto
    ),
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
            (\+ aparece_en(Nodo.name, Contexto_Atom, Tipo) -> assertz(aparece_en(Nodo.name, Contexto_Atom, Tipo)) ; true)
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
            assertz(relacion(Tipo, NodoOrigen.name, NodoDestino.name, Link.value, Contexto_Atom))
        )
    ).
