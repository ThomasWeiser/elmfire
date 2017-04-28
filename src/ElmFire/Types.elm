module ElmFire.Types exposing (..)

{- Internal representation of locations

   Unfortunately we cannot use a union type here.

   The implementation of the effect manager demands Location to be a comparable type.
   Union types are not comparable (in Elm 0.17).
   Lists are the only aggregate type that transports comparability of its element type.
-}


type alias LocationSpec =
    List ( String, String )


type Location
    = Location LocationSpec
