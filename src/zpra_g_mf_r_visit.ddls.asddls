@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Visit'
define view entity ZPRA_G_MF_R_VISIT
  as select from zpra_g_mf_a_vst
  association to parent ZPRA_G_MF_R_MUSICFESTIVAL as _MusicFestival
    on $projection.ParentUuid = _MusicFestival.UUID
  association [1..1] to ZPRA_G_MF_R_VISITOR as _Visitor
    on $projection.VisitorUuid = _Visitor.UUID
  association [1..1] to ZPRA_G_MF_I_VISIT_STATUS_VH as _VisitStatus
    on $projection.Status = _VisitStatus.Value
{
  key uuid                  as Uuid,
  parent_uuid               as ParentUuid,
  visitor_uuid              as VisitorUuid,
  artist_indicator          as ArtistIndicator,
  status                    as Status,
  local_last_changed_at     as LocalLastChangedAt,
  _MusicFestival,
  _Visitor,
  _VisitStatus
}
