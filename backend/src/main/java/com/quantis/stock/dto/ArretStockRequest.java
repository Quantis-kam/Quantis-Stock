package com.quantis.stock.dto;

import lombok.Data;

@Data
public class ArretStockRequest {
    private Long depotId;
    private String notes;
}
