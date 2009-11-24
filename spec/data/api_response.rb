unless defined?(API_RESPONSE)
API_RESPONSE=<<STRING
Content-Type: api/response
Content-Length: 747

 <?xml version="1.0"?>
<conferences>
  <conference name="01" member-count="1" rate="8000" wait_mod="true" running="true" answered="true" enforce_min="true" dynamic="true">
    <members>
      <member>
        <id>1</id>
        <flags>
          <can_hear>true</can_hear>
          <can_speak>true</can_speak>
          <talking>false</talking>
          <has_video>false</has_video>
          <has_floor>true</has_floor>
          <is_moderator>false</is_moderator>
          <end_conference>false</end_conference>
        </flags>
        <uuid>0dbef194-d0a2-11de-adde-0d98eb8987c6</uuid>
        <caller_id_name>Lon</caller_id_name>
        <caller_id_number>1000</caller_id_number>
      </member>
    </members>
  </conference>
</conferences>
STRING
end