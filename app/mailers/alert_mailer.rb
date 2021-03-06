#!/bin/env ruby
# encoding: utf-8
class AlertMailer < ActionMailer::Base
  default from: "TenderAlerts@tendermonitor.ge"

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
    puts "emailing "+user.email
    if user.language == "ქართული"
      I18n.locale = 'ka'
    else
      I18n.locale = 'en'
    end
    @searchUpdates = []
    @supplierUpdates = []
    @tenderUpdates = []
    @procurerUpdates = []

    
    if updates[:searches]
      @searchUpdates = updates[:searches]
    end
    
    if updates[:supplierWatches]
      updates[:supplierWatches].each do |watch|
        supplier = Organization.where(:id => watch.supplier_id).first
        if supplier
          supplierObject = {:id => supplier.id, :name => supplier.name, :bids => [], :agreements => []}
          if watch.diff_hash
            items = watch.diff_hash.split("#")
            items.each do |item|
              bidIndex = item.index('bid')
              agreementIndex = item.index('agreement')
              if bidIndex
                bidIndex = item.index('d') + 1
                bidID = item[bidIndex..-1]
                bidObject = Bidder.where(:id => bidID).first
                if bidObject
                  tender = Tender.where(:id => bidObject.tender_id).first
                  if tender
                    supplierObject[:bids].push( {:id => tender.id, :spa => tender.tender_registration_number, :value => bidObject.last_bid_amount} )
                  end
                end
              elsif agreementIndex
                agreementIndex = item.index('t') + 1
                agreementID = item[agreementIndex..-1]
                agreementObject = Agreement.where(:id => agreementID).first
                if agreementObject
                  tender = Tender.where(:id => agreementObject.tender_id).first
                  if tender
                    supplierObject[:agreements].push( {:id => tender.id, :spa => tender.tender_registration_number, :value => agreementObject.amount} )
                  end
                end
              end
              @supplierUpdates.push(supplierObject)
            end
          end
        end
      end
    end
    
    if updates[:procurerWatches]
      updates[:procurerWatches].each do |watch|
        procurer = Organization.where(:id => watch.procurer_id).first
        if procurer
          procurerObject = {:id => procurer.id, :name => procurer.name, :tenders => []}
          if watch.diff_hash
            items = watch.diff_hash.split("#")
            items.each do |item|
              tenderIndex = item.index('tender')
              if tenderIndex != nil
                tenderIndex = item.index('r') + 1
                tenderID = item[tenderIndex..-1]
                tender = Tender.where(:id => tenderID).first
                if tender
                  procurerObject[:tenders].push( {:id => tender.id, :spa => tender.tender_registration_number, :value => tender.estimated_value} )
                end
              end
            end
          end
          @procurerUpdates.push(procurerObject)
        end   
      end
    end

    if updates[:tenderWatches]
      updates[:tenderWatches].each do |watch|
        tender = Tender.where(:url_id => watch.tender_url).first
        if tender
          tenderObject = {:id => tender.id, :spa => tender.tender_registration_number, :changes => []}
          if watch.diff_hash
            items = watch.diff_hash.split("#")
            items.each do |item|
              if item.index("/")
                info = item.split("/")
                new = tender.attributes[info[0]]
                field = tender.getHumanReadableAttributeName(info[0])
                change = {:field => field, :old => info[1], :new => new}
                tenderObject[:changes].push(change)
              end
            end
          end
          @tenderUpdates.push(tenderObject)
        end
      end
    end
       
    mail(:to => user.email, :subject => t("digest_subject"))
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
