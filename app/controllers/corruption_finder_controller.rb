class CorruptionFinderController < ApplicationController

  def index
  end

  def search
    criteria = params[:criteria]
  
    if criteria == "all"
      tenders = {}
      count = 0
      TenderCorruptionFlag.find_each do | flag |
        riskAssessment = tenders[flag.tender_id]
        if not riskAssessment
          riskAssessment = {}
          riskAssessment[:total] = 0
          riskAssessment[:indicators] = []
        end
        indicator = CorruptionIndicator.find( flag.corruption_indicator_id )
        riskAssessment[:total] = riskAssessment[:total] + (indicator.weight * flag.value)
        riskAssessment[:indicators].push(indicator)
        tenders[flag.tender_id] = riskAssessment
      end
      
      def mysort(a,b)
        if b[:total] > a[:total]
          return 1
        else
          return -1
        end
      end
      tenders = tenders.sort { |a,b| mysort(a[1],b[1])}
      
      @riskyTenders = []
      count = 0
      tenders.each do |tender_id, risk|
        count = count + 1
        if count > 25
          break
        end
        tenderData = {}
        tenderData[:id] = tender_id
        tenderData[:code] = Tender.find(tender_id).tender_registration_number
        tenderData[:value] = risk[:total]
        tenderData[:info] = ""
        risk[:indicators].each do |indicator|
          tenderData[:info]+=indicator.name+", "
        end
        tenderData[:info].chop!.chop!
        @riskyTenders.push(tenderData)
      end

      respond_to do |format|  
        format.js   
      end
    end
    
    puts @riskyTenders
    puts "BLAJ"
  end
end