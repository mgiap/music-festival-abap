@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Visitor Value Help'
@Search.searchable: true
define view entity ZPRA_G_MF_I_VISITOR
  as select from zpra_g_mf_a_vstr
{
  @ObjectModel.text.element: ['Name']   
  key uuid  as Uuid,
  @Search.defaultSearchElement: true
  @Semantics.text: true                
  name      as Name,
  email     as Email
}
