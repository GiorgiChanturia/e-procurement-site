class AlertMailer < ActionMailer::Base
  default from: "alerts@tendermonitor.ge"

  def search_alert(user, search, searchUpdates)
    @search = search
    @updates = searchUpdates
    subject = ""
    if search.searchtype == "supplier"
      subject = "New Supplier Search Update"
    elsif search.searchtype == "procurer"
      subject = "New Procurer Search Update"
    else
      subject = "New Tender Search Update"
    end   
    mail(:to => user.email, :subject => "New Search Updates")
  end

  def tender_alert(user, tender, attributes)
    @tender = tender
    @attributes = attributes
    mail(:to => user.email, :subject => "New Tender Updates")
  end

  def supplier_alert(user, supplier, attributes)
    @supplier = supplier
    @attributes = attributes
    mail(:to => user.email, :subject => "New Supplier Updates")
  end

  def procurer_alert(user, procurer, attributes)
    @supplier = procurer
    @attributes = attributes
    mail(:to => user.email, :subject => "New Procurer Updates")
  end

  def daily_digest(user, updates)
    @updates = updates
    puts "emailing "+user.email
    mail(:to => user.email, :subject => "Your TenderMonitor Updates")
  end

  def data_process_started()
    mail(:to => "Chris@transparency.ge", :subject => "data process started")
  end

  def data_process_finished()
    mail(:to => "Chris@transparency.ge", :subject => "data process finished")
  end

  def meta_started()
    mail(:to => "Chris@transparency.ge", :subject => "meta started")
  end
end
