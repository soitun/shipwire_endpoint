# The Order id we use to track is the Spree Shipment Number
#
# The <Bookmark> tag currently has three options:
# “1″ for a dump of everything in the account
# “2″ for a dump of everything since the last bookmark
# “3″ for a dump of everything since the last bookmark AND reset the bookmark to right now
class OrderTracking < ShipWire

  def consume
    response = self.class.post('/TrackingServices.php', :body => xml_body)

    if response['TrackingUpdateResponse']['Status'] == 'Error'

      return [ 500, { 'message_id' => message_id,
               'shipwire_response' => response['TrackingUpdateResponse'] } ]

    else
      msgs = []

      response['TrackingUpdateResponse']['Order'].each do |shipment|
        next unless shipment['shipped'] == 'YES'
        msgs << create_message(shipment)
      end

      return [ 200, { 'message_id' => message_id,
               'messages' => msgs,
               'shipwire_response' => response['TrackingUpdateResponse'] } ]

    end
  end

  private

  def create_message(shipment)
    {
       key: 'shipment:dispatch',
       payload: {
         shipment_number: shipment['id'],
         tracking_number: shipment['TrackingNumber']['__content__'].strip,
         tracking_url: shipment['TrackingNumber']['href'],
         carrier: shipment['TrackingNumber']['carrier'],
         shipped_date: Time.parse(shipment['shipDate']).utc,
         delivery_date: Time.parse(shipment['expectedDeliveryDate']).utc }
    }
  end

  def xml_body
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.TrackingUpdate {
        xml.Username config[:username]
        xml.Password config[:password]
        xml.Server server_mode
        xml.Bookmark '2'
      }
    end
    builder.to_xml
  end

end
