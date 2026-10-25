package com.example.amqdemo.model;

import java.io.Serializable;

/**
 * The object sent to the broker.
 *
 * Keep the fields flat and simple (numbers, strings, booleans): the Delphi
 * class TOrder mirrors them as published properties with the same names.
 */
public class Order implements Serializable {

    private static final long serialVersionUID = 1L;

    private long id;
    private String product;
    private int quantity;
    private double price;
    private String created; // ISO-8601

    public Order() {
    }

    public Order(long id, String product, int quantity, double price, String created) {
        this.id = id;
        this.product = product;
        this.quantity = quantity;
        this.price = price;
        this.created = created;
    }

    public long getId() {
        return id;
    }

    public void setId(long id) {
        this.id = id;
    }

    public String getProduct() {
        return product;
    }

    public void setProduct(String product) {
        this.product = product;
    }

    public int getQuantity() {
        return quantity;
    }

    public void setQuantity(int quantity) {
        this.quantity = quantity;
    }

    public double getPrice() {
        return price;
    }

    public void setPrice(double price) {
        this.price = price;
    }

    public String getCreated() {
        return created;
    }

    public void setCreated(String created) {
        this.created = created;
    }

    @Override
    public String toString() {
        return "Order[id=" + id + ", product=" + product + ", quantity=" + quantity
                + ", price=" + price + ", created=" + created + "]";
    }
}
