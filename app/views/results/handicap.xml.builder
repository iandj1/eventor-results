xml.instruct!
xml.ResultList(xmlns: "http://www.orienteering.org/datastandard/3.0", iofVersion: "3.0", creator: "OACT Result WebApp") {
  xml.Event {
    xml.Name @event.name
  }
  xml.ClassResult {
    xml.Class {
      xml.Name "Handicap"
    }
    @results.each_with_index do |result, index|
      xml.PersonResult {
        xml.Person {
          xml.Id result.eventor_id
          xml.Name {
            xml.Family result.family_name
            xml.Given result.given_name
          }
        }
        if result.organisation
          xml.Organisation {
            xml.Id result.organisation["Id"]
            xml.Name result.organisation["Name"]
          }
        end
        xml.Result {
          xml.Position index + 1
          xml.Status 'OK'
        }
      }
    end
  }
}