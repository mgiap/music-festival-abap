CLASS LHC_ZPRA_G_MF_R_MUSICFESTIVAL DEFINITION
  INHERITING FROM CL_ABAP_BEHAVIOR_HANDLER.

  PRIVATE SECTION.

    METHODS:
      get_global_authorizations FOR GLOBAL AUTHORIZATION
        IMPORTING
          REQUEST requested_authorizations FOR MusicFestivals
        RESULT result,

        get_global_auth_visit FOR GLOBAL AUTHORIZATION
          IMPORTING
            REQUEST requested_authorizations FOR Visit
          RESULT result,

      validateFestival FOR VALIDATE ON SAVE
        IMPORTING keys FOR MusicFestivals~validateFestival,

      validateVisitCreation FOR VALIDATE ON SAVE
        IMPORTING keys FOR Visit~validateVisitCreation,

      determineStatus FOR DETERMINE ON MODIFY
        IMPORTING keys FOR MusicFestivals~determineStatus,

      determineVisitStatus FOR DETERMINE ON MODIFY
        IMPORTING keys FOR Visit~determineVisitStatus,

      determineAvailableSeats FOR DETERMINE ON SAVE
        IMPORTING keys FOR Visit~determineAvailableSeats,

      determineInitialSeats FOR DETERMINE ON MODIFY
        IMPORTING keys FOR MusicFestivals~determineInitialSeats,

      cancel FOR MODIFY
        IMPORTING keys FOR ACTION Visit~cancel
        RESULT result,

      publish FOR MODIFY
        IMPORTING keys FOR ACTION MusicFestivals~publish
        RESULT result.

ENDCLASS.

CLASS LHC_ZPRA_G_MF_R_MUSICFESTIVAL IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.

    METHOD get_global_auth_visit.
    ENDMETHOD.

METHOD validateFestival.

  READ ENTITIES OF ZPRA_G_MF_R_MUSICFESTIVAL IN LOCAL MODE
    ENTITY MusicFestivals
    FIELDS ( Title EventDateTime VisitorsFeeAmount FreeVisitorSeats MaxVisitorsNumber )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_data).

  LOOP AT lt_data INTO DATA(ls_data).

    IF ls_data-Title IS INITIAL OR ls_data-EventDateTime IS INITIAL.
      APPEND VALUE #( %tky = ls_data-%tky ) TO failed-MusicFestivals.
      APPEND VALUE #(
        %tky = ls_data-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text     = 'Title and Event Date are required'
        )
      ) TO reported-MusicFestivals.
    ENDIF.

    IF ls_data-VisitorsFeeAmount < 0.
      APPEND VALUE #( %tky = ls_data-%tky ) TO failed-MusicFestivals.
      APPEND VALUE #(
        %tky = ls_data-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text     = 'Price cannot be negative'
        )
        %element-VisitorsFeeAmount = if_abap_behv=>mk-on
      ) TO reported-MusicFestivals.
    ENDIF.

    IF ls_data-FreeVisitorSeats > ls_data-MaxVisitorsNumber.
      APPEND VALUE #( %tky = ls_data-%tky ) TO failed-MusicFestivals.
      APPEND VALUE #(
        %tky = ls_data-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text     = 'Available seats cannot exceed max number'
        )
        %element-FreeVisitorSeats = if_abap_behv=>mk-on
      ) TO reported-MusicFestivals.
    ENDIF.

  ENDLOOP.

ENDMETHOD.

  METHOD publish.

    MODIFY ENTITIES OF ZPRA_G_MF_R_MUSICFESTIVAL IN LOCAL MODE
      ENTITY MusicFestivals
      UPDATE FIELDS ( Status )
      WITH VALUE #(
        FOR key IN keys (
          UUID   = key-UUID
          Status = 'P'
        )
      ).

    READ ENTITIES OF ZPRA_G_MF_R_MUSICFESTIVAL IN LOCAL MODE
      ENTITY MusicFestivals
      ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #(
      FOR ls IN lt_result (
        %tky   = ls-%tky
        %param = ls
      )
    ).

  ENDMETHOD.

METHOD cancel.

  MODIFY ENTITIES OF ZPRA_G_MF_R_MUSICFESTIVAL IN LOCAL MODE
    ENTITY Visit
    UPDATE FIELDS ( Status )
    WITH VALUE #(
      FOR key IN keys
        ( %tky  = key-%tky
          Status = 'C' )
    ).

  READ ENTITIES OF ZPRA_G_MF_R_MUSICFESTIVAL IN LOCAL MODE
    ENTITY Visit
    ALL FIELDS
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_result).

  result = VALUE #(
    FOR ls IN lt_result
      ( %tky        = ls-%tky
        %param-%tky = ls-%tky
        %param-VisitorUuid        = ls-VisitorUuid
        %param-ArtistIndicator    = ls-ArtistIndicator
        %param-Status             = ls-Status
        %param-LocalLastChangedAt = ls-LocalLastChangedAt
      )
  ).

ENDMETHOD.

METHOD determineStatus.

  READ ENTITIES OF ZPRA_G_MF_R_MUSICFESTIVAL IN LOCAL MODE
    ENTITY MusicFestivals
    FIELDS ( Status )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_data).

  MODIFY ENTITIES OF ZPRA_G_MF_R_MUSICFESTIVAL IN LOCAL MODE
    ENTITY MusicFestivals
    UPDATE FIELDS ( Status )
    WITH VALUE #(
      FOR ls IN lt_data
        WHERE ( Status IS INITIAL )
        ( %tky  = ls-%tky
          Status = 'I' )
    ).

ENDMETHOD.

METHOD determineInitialSeats.

  READ ENTITIES OF ZPRA_G_MF_R_MUSICFESTIVAL IN LOCAL MODE
    ENTITY MusicFestivals
    FIELDS ( MaxVisitorsNumber )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_data).

  LOOP AT lt_data INTO DATA(ls_data).

    SELECT COUNT(*) FROM zpra_g_mf_a_vst
      WHERE parent_uuid = @ls_data-UUID
        AND status = 'B'
        AND artist_indicator = ''
      INTO @DATA(lv_booked).

    MODIFY ENTITIES OF ZPRA_G_MF_R_MUSICFESTIVAL IN LOCAL MODE
      ENTITY MusicFestivals
      UPDATE FIELDS ( FreeVisitorSeats )
      WITH VALUE #( (
        %tky             = ls_data-%tky
        FreeVisitorSeats = ls_data-MaxVisitorsNumber - lv_booked
      ) ).

  ENDLOOP.

ENDMETHOD.


  METHOD determineVisitStatus.
   MODIFY ENTITIES OF ZPRA_G_MF_R_MUSICFESTIVAL IN LOCAL MODE
    ENTITY Visit
    UPDATE FIELDS ( Status )
    WITH VALUE #(
      FOR key IN keys
        ( %tky  = key-%tky
          Status = 'B' )
    ).
  ENDMETHOD.

  METHOD validateVisitCreation.

      READ ENTITIES OF ZPRA_G_MF_R_MUSICFESTIVAL IN LOCAL MODE
        ENTITY Visit
        FIELDS ( ParentUuid )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_visits).

      READ ENTITIES OF ZPRA_G_MF_R_MUSICFESTIVAL IN LOCAL MODE
        ENTITY MusicFestivals
        FIELDS ( Status )
        WITH VALUE #(
          FOR visit IN lt_visits
            ( %tky-UUID = visit-ParentUuid )
        )
        RESULT DATA(lt_festivals).

      LOOP AT lt_visits INTO DATA(ls_visit).
        READ TABLE lt_festivals INTO DATA(ls_festival)
          WITH KEY UUID = ls_visit-ParentUuid.
        IF ls_festival-Status <> 'P'.
          APPEND VALUE #( %tky = ls_visit-%tky ) TO failed-Visit.
          APPEND VALUE #(
            %tky = ls_visit-%tky
            %msg = new_message_with_text(
              severity = if_abap_behv_message=>severity-error
              text     = 'Visitor can only be added to a Published festival'
            )
          ) TO reported-Visit.
        ENDIF.
      ENDLOOP.

    ENDMETHOD.

METHOD determineAvailableSeats.

  READ ENTITIES OF ZPRA_G_MF_R_MUSICFESTIVAL IN LOCAL MODE
    ENTITY Visit
    FIELDS ( ParentUuid )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_visits).

  LOOP AT lt_visits INTO DATA(ls_visit).

    READ ENTITIES OF ZPRA_G_MF_R_MUSICFESTIVAL IN LOCAL MODE
      ENTITY MusicFestivals
        FIELDS ( UUID MaxVisitorsNumber )
        WITH VALUE #( ( %tky-UUID = ls_visit-ParentUuid ) )
        RESULT DATA(lt_festivals)
      ENTITY MusicFestivals BY \_Visit
        FIELDS ( Status ArtistIndicator )
        WITH VALUE #( ( %tky-UUID = ls_visit-ParentUuid ) )
        RESULT DATA(lt_all_visits).

    READ TABLE lt_festivals INTO DATA(ls_festival) INDEX 1.
    CHECK ls_festival IS NOT INITIAL.

    DATA lv_booked TYPE i.
    lv_booked = REDUCE i(
      INIT count = 0
      FOR visit IN lt_all_visits
      WHERE ( Status = 'B' AND ArtistIndicator = '' )
      NEXT count = count + 1
    ).

    MODIFY ENTITIES OF ZPRA_G_MF_R_MUSICFESTIVAL IN LOCAL MODE
      ENTITY MusicFestivals
      UPDATE FIELDS ( FreeVisitorSeats )
      WITH VALUE #( (
        UUID             = ls_festival-UUID
        FreeVisitorSeats = ls_festival-MaxVisitorsNumber - lv_booked
      ) ).

  ENDLOOP.

ENDMETHOD.

ENDCLASS.
